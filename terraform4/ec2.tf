data "aws_ami" "my_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "rackula" {
  ami                    = data.aws_ami.my_ami.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.my_subnet_public.id
  vpc_security_group_ids = [aws_security_group.my_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.my_ssm_profile.name
  user_data              = templatefile("userdata.sh", {})

  tags = {
    Name = "tf-rackula"
  }
}