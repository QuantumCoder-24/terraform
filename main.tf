
provider "aws" {
    region = "us-east-1"
} 

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "myip" {}
variable "instance-type" {}
variable "public_key_location" {}

resource "aws_vpc" "myapp-vpc" {
  cidr_block = var.vpc_cidr_block
  tags = {
    Name: "${var.env_prefix}-vpc"
  }
}

resource "aws_subnet" "myapp-subnet-1" {
  vpc_id = aws_vpc.myapp-vpc.id
  cidr_block = var.subnet_cidr_block
  availability_zone = var.avail_zone
  tags = {
    Name: "${var.env_prefix}-subnet-1"
  }
}

resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id
  tags = {
    Name: "${var.env_prefix}-igw"
  }
}
/*resource "aws_route_table" "myapp-route-table" {
  vpc_id = aws_vpc.myapp-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    Name: "${var.env_prefix}-rtb"
  }
}*/

/*resource "aws_route_table_association" "a-rtb-subnet" {
    subnet_id = aws_subnet.myapp-subnet-1.id
    route_table_id = aws_route_table.myapp-route-table.id
}*/

resource "aws_default_route_table" "main-rtb" {
  default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myapp-igw.id
  }
  tags = {
    Name: "${var.env_prefix}-mainrtb"
  }
}

resource "aws_security_group" "myapp-sg" {
    name = "myapp-sg"
    vpc_id = aws_vpc.myapp-vpc.id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.myip]
    }
    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

     egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        prefix_list_ids = []
        cidr_blocks = ["0.0.0.0/0"]
}
tags = {
  Name: "${var.env_prefix}-sg"
}  
}

data "aws_ami" "latest-amazon-linux-image" {
  
  most_recent = true
  owners = ["amazon"]
  filter {
    name = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

output "aws-ami" {
  value = data.aws_ami.latest-amazon-linux-image.id
}

resource "aws_instance" "myapp-server" {
  ami = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance-type
  availability_zone = var.avail_zone

  subnet_id = aws_subnet.myapp-subnet-1.id
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]

  associate_public_ip_address = true

  /* Download the key directly from the AWS*/

  /*key_name = "server-key-pair"*/ 

  key_name = aws_key_pair.ssh-key.key_name

user_data = <<EOF
                #!/bin/bash
                sudo yum update -y && sudo install -y docker
                sudo systemctl docker
                sudo usermod -aG docker ec2-user
                docker run -p 8080:80 nginx
              EOF

  tags = {
    Name: "${var.env_prefix}-server"
  }
}

resource "aws_key_pair" "ssh-key" {
    key_name = "server-key"
    public_key = file (var.public_key_location)
  
}

output "ec2-public-ip" {
    value = aws_instance.myapp-server.public_ip
  
}