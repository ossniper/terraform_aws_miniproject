provider "aws" {
  region = "us-east-1"
# Kindly note that using Static or Hardcoded credentials is not recommended in Production environment
# There are other methods.. which will be presented in my next test project.. Thanks
  access_key = "Abcdefgh1234567890"   
  secret_key = "Z0987654321ABCDEFGHIJKLMNO5"   
"

}

# Create a VPC
resource "aws_vpc" "ub_server" {
  cidr_block = "172.16.0.0/16"

  tags = {
    Name = "ubserver_vpc_test"
  }

}

# create an internet_gateway

resource "aws_internet_gateway" "gw_secure" {
  vpc_id = aws_vpc.ub_server.id

  tags = {
    Name = "ubserver_gateway"
  }
}


# Create a route table
resource "aws_route_table" "ubs_route" {
  vpc_id = aws_vpc.ub_server.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw_secure.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw_secure.id
  }

  tags = {
    Name = "My_securedRoute"
  }
}

# create a subnet

resource "aws_subnet" "priv_10_1a" {
  vpc_id     = aws_vpc.ub_server.id
  cidr_block = "172.16.10.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private_subnet"
  }
}
# associate subnet with Route Table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.priv_10_1a.id
  route_table_id = aws_route_table.ubs_route.id
}

# create a security group

resource "aws_security_group" "secure_ubser" {
  name        = "secure_allow_ubserver"
  description = "Allow SSH_TLS inbound traffic"
  vpc_id      = aws_vpc.ub_server.id

  ingress {
    description = "HTTPS_TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "icmp from VPC"
    from_port   = 1
    to_port     = 1
    protocol    = "All"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ubserver_securitygr"
  }
}

# create a network interface 

resource "aws_network_interface" "net_int" {
  subnet_id       = aws_subnet.priv_10_1a.id
  private_ips     = ["172.16.10.50"]
  security_groups = [aws_security_group.secure_ubser.id]

  # attachment {
  #   instance     = aws_instance.my_webserver.id
  #   device_index = 1
  # }
}

# create an Elastic IP address

resource "aws_eip" "eip_lb" {
  instance = aws_instance.my_webserver.id
  vpc      = true
  network_interface = aws_network_interface.net_int.id
  associate_with_private_ip = "172.16.10.50"
  depends_on = [aws_internet_gateway.gw_secure]

}

# create an ubuntu webserver instance

resource "aws_instance" "my_webserver" {
  ami               = "ami-03d315ad33b9d49c4"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1b"
  key_name = "MS"
  

  network_interface  {
    device_index = 0
    network_interface_id = aws_network_interface.net_int.id
  }


  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo ufw app list
                sudo ufw allow 'Apache Full'
                sudo ufw allow 'Apache'
                sudo ufw status
                sudo systemctl status apache2
                sudo bash -c 'echo This my first webserver, Deployed using Terraform and AWS Provider > /var/www/html/index.html'
                EOF


  tags = {
      Name = "my_first_webserver"
  }
}