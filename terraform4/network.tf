resource "aws_vpc" "my_vpc" {
  cidr_block = "10.20.0.0/16"
  tags = {
    Name = "tf-vpc"
  }
}

resource "aws_subnet" "my_subnet_public" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = var.az
  map_public_ip_on_launch = true
  tags = {
    Name = "tf-subnet-public"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "tf-igw"
  }
}

resource "aws_route_table" "my_route_table_public" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "tf-rt-public"
  }
}

resource "aws_route" "my_route_internet" {
  route_table_id         = aws_route_table.my_route_table_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw.id
}

resource "aws_route_table_association" "my_subnet_link" {
  subnet_id      = aws_subnet.my_subnet_public.id
  route_table_id = aws_route_table.my_route_table_public.id
}