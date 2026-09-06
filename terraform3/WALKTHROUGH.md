# terraform3 walkthrough

End state: a VPC with a public server reachable by IP/SSM, and a private
server with **no public IP and no inbound security-group rule**, exposed to
the internet only through an outbound Cloudflare Tunnel.

## 1. Network (`network.tf`)

Used the `terraform-aws-modules/vpc/aws` module instead of hand-rolled
`aws_vpc`/`aws_subnet` resources:

- VPC `10.20.0.0/16`
- Public subnet `10.20.1.0/24`, private subnet `10.20.2.0/24`
- `enable_nat_gateway = true`, `single_nat_gateway = true` — this alone made
  the module create the NAT Gateway, its Elastic IP, and the private route
  table's `0.0.0.0/0 -> nat` route for us. No manual NAT/route-table
  resources were needed.

## 2. Security groups (`security.tf`)

Also moved to the `terraform-aws-modules/security-group/aws` module:

- `my_sg` (public): ingress `tcp/80` from `0.0.0.0/0`, egress all — for the
  public server.
- `my_sg_private`: **egress only, no ingress rule at all**. The private
  server never accepts inbound connections; it only calls out to Cloudflare.

## 3. EC2 instances (`ec2.tf`)

Used `terraform-aws-modules/ec2-instance/aws` for both instances.

- `module.my_server_public`: in the public subnet, `my_sg`, runs
  `userdata.sh`.
- `module.my_server_private`: in the private subnet, `my_sg_private`, runs
  `userdata-tunnel.sh` with the Cloudflare tunnel token injected via
  `templatefile()`.

The tunnel token is read from SSM Parameter Store via a data source:

```hcl
data "aws_ssm_parameter" "token" {
  name            = "/devops-bootcamp-2026/tunnel-token"
  with_decryption = true
}
```

**Tradeoff accepted here**: because this is a `data` source read by local
Terraform credentials, the decrypted token ends up in plaintext in
`terraform.tfstate` and in the instance's `user_data` (visible via
`aws ec2 describe-instance-attribute`). A more locked-down alternative would
be to have `userdata-tunnel.sh` call `aws ssm get-parameter --with-decryption`
itself on the instance (using the instance's own IAM role), so the token
never touches state or user-data. We went with the simpler data-source
approach for this exercise.

## 4. Boot scripts

`userdata.sh` (public server):
```bash
#!/bin/bash
curl -fsSL https://get.docker.com | sh
id ssm-user &>/dev/null || useradd -m ssm-user
usermod -aG docker ssm-user
docker run -d -p 80:80 nginx
```

`userdata-tunnel.sh` (private server):
```bash
#!/bin/bash
curl -fsSL https://get.docker.com | sh
docker run -d -p 80:80 nginx
docker run -d --network host cloudflare/cloudflared:latest \
  tunnel --no-autoupdate run --token ${tunnel_token}
```
`cloudflared` runs with `--network host` so it can reach the `nginx`
container via `localhost:80` on the same instance.

## 5. Bugs hit along the way

- **Nested git repo**: `terraform1` had its own `.git` inside the root repo,
  so it showed up as a submodule/gitlink instead of tracked files. Fixed by
  deleting the nested `.git` and re-adding the folder normally from the root.
- **`ssm-user` sudo broken**: `userdata.sh`'s `useradd -m ssm-user` ran
  before the SSM Agent's own first-connect provisioning, which normally
  creates that user *and* grants it passwordless sudo. Because the user
  already existed, the agent skipped that setup, leaving `sudo` broken.
  Fixed live via `aws ssm send-command` writing
  `/etc/sudoers.d/ssm-agent-users`. (This fix lives only on the running
  instance — if it's ever replaced, the same issue will resurface unless
  `userdata.sh` is changed to stop pre-creating the user.)
- **`docker ps` "empty" confusion**: turned out to be checking inside the
  SSM session on the EC2 instance, not locally — nginx was running fine.

## 6. Cloudflare Tunnel setup (done outside Terraform)

1. Created a tunnel named `terraform3` in the Cloudflare Zero Trust
   dashboard (Networks -> Tunnels & Mesh).
2. Selected **Linux** as the connector OS to get the correct
   `cloudflared service install <token>` command (the token is what's
   embedded in `userdata-tunnel.sh` via SSM).
3. Stored the token in SSM Parameter Store (SecureString), outside the repo:
   ```
   aws ssm put-parameter --name /devops-bootcamp-2026/tunnel-token \
     --type SecureString --value file:///path/to/token.txt \
     --region ap-southeast-1
   ```
4. Under the tunnel's **Published application routes** tab (not "Hostname
   routes" — that one requires visitors to install the Cloudflare One/WARP
   client, meant for private network access, not a public site), added a
   route: hostname `terraform3.hasb.dev` -> `HTTP` -> `localhost:80`.
5. Verified: `curl https://terraform3.hasb.dev/` returns `200` with
   `server: cloudflare`, serving the private instance's nginx page — with
   that instance having no public IP and no inbound security-group rule.

## 7. Applying

```
cd terraform3
terraform init
terraform plan
terraform apply
```

Outputs (`outputs.tf`):
- `server_ip_public` — public server's IP
- `ssm_command_public` — ready-to-run SSM session command for the public
  server
