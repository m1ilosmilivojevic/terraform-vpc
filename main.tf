provider "aws" {
    region  = "eu-north-1"
}

resource "aws_vpc" "tf_custom_vpc"{
    cidr_block  = "10.0.0.0/16"
    enable_dns_support  = true
    enable_dns_hostnames    = true
    tags = { Name = "tf-custom-vpc"}
}

resource "aws_subnet" "public"{
    vpc_id  = aws_vpc.tf_custom_vpc.id
    cidr_block  = "10.0.1.0/24"
    availability_zone   = "eu-north-1a"
    map_public_ip_on_launch = true
    tags = { Name = "public-subnet"}
  
}

resource "aws_subnet" "private"{
    vpc_id  = aws_vpc.tf_custom_vpc.id
    cidr_block  = "10.0.2.0/24"
    availability_zone   = "eu-north-1a"
    tags = { Name = "private-subnet"}
  
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.tf_custom_vpc.id
  tags = { Name = "main-gateway"}
  
}




resource "aws_route_table" "public" {
  vpc_id = aws_vpc.tf_custom_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = { Name = "public-route"}
}



resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.gw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.tf_custom_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {Name = "private-route"}
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}



resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
  description = "Allow SSH access from anywhere"
  vpc_id      = aws_vpc.tf_custom_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open SSH for testing, lock later if needed
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AllowSSH"
  }
}





# Security group allowing SSH
resource "aws_security_group" "private_ec2_sg" {
  name        = "private-ec2-sg"
  description = "Allow SSH only from public EC2"
  vpc_id      = aws_vpc.tf_custom_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_ssh.id] # Only from public EC2's SG
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}







# Public EC2 instance
resource "aws_instance" "tf_public_ec2" {
  ami                    = "ami-0c1ac8a41498c1a9c" # Ubuntu 22.04 LTS in eu-north-1
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  key_name               = # put your key here
  tags = { Name = "Terraform Public EC2"}
}

# Private EC2 instance
resource "aws_instance" "tf_private_ec2" {
  ami                    = "ami-0c1ac8a41498c1a9c"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.private_ec2_sg.id]
  key_name               = "miles-key2"
  tags = { Name = "Private EC2"}
}

