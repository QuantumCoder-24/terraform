
resource "aws_security_group" "myapp-sg" {
    name = "myapp-sg"
    vpc_id = var.vpc_id

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
    values = [var.image_name]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}


resource "aws_instance" "myapp-server" {
  ami = data.aws_ami.latest-amazon-linux-image.id
  instance_type = var.instance-type
  availability_zone = var.avail_zone

  subnet_id = var.subnet_id
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

