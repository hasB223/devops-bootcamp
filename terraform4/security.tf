resource "aws_security_group" "my_sg" {
  name   = "tf-rackula-sg"
  vpc_id = aws_vpc.my_vpc.id
  tags   = { Name = "tf-rackula-sg" }
}

# Rackula frontend (docker compose persist maps host 8080 -> container 8080)
resource "aws_vpc_security_group_ingress_rule" "my_inbound_http" {
  security_group_id = aws_security_group.my_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
}

resource "aws_vpc_security_group_egress_rule" "my_outbound_all" {
  security_group_id = aws_security_group.my_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}