provider "aws" {
  region = var.region
}

# -----------------------------
# VPC
# -----------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "ad-lab-vpc"
  }
}

# -----------------------------
# Subnet
# -----------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "ad-lab-public-subnet"
  }
}

# -----------------------------
# Internet Gateway
# -----------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "ad-lab-igw"
  }
}

# -----------------------------
# Route Table
# -----------------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "ad-lab-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# -----------------------------
# Security Group
# -----------------------------
resource "aws_security_group" "ad_sg" {
  name        = "ad-lab-sg"
  description = "Allow RDP, LDAP, LDAPS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ip]
  }

  ingress {
    description = "LDAP"
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "LDAPS"
    from_port   = 636
    to_port     = 636
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ad-lab-sg"
  }
}

# -----------------------------
# Windows EC2 Instance
# -----------------------------
resource "aws_instance" "dc" {
  ami           = var.windows_ami
  instance_type = var.instance_type
  subnet_id     = aws_subnet.public.id
  security_groups = [
    aws_security_group.ad_sg.id
  ]

  key_name = var.keypair_name

  user_data = templatefile("powershell/ad-setup.ps1.tpl", { # Runs AD install script
  domain_name = var.domain_name
  netbios_name = var.netbios_name
  ad_password = var.ad_password
})

  tags = {
    Name = "AD-DomainController"
  }
}
