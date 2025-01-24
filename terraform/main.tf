terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  # These tags will automatically apply to all resources
  default_tags {
    tags = {
      "${DEPLOY_ID}" = "${DEPLOY_ID}"
      "${ENV}"                        = "true"
    }
  }
}

# Key pair (adjust the file path if needed)
resource "aws_key_pair" "kp" {
  key_name   = "${KEY_NAME}"
  public_key = file("${PUB_KEY_PATH}")
}

resource "aws_vpc" "cluster_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.cluster_vpc.id
}

resource "aws_subnet" "cluster_subnet" {
  count      = 2
  vpc_id     = aws_vpc.cluster_vpc.id
  cidr_block = "10.0.${count.index}.0/24"
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.cluster_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "a" {
  count             = length(aws_subnet.cluster_subnet.*.id)
  subnet_id         = aws_subnet.cluster_subnet[count.index].id
  route_table_id    = aws_route_table.public_rt.id
}

resource "aws_security_group" "cluster_sg" {
  vpc_id = aws_vpc.cluster_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

##################################################
# Create 5 GPU instances
##################################################
resource "aws_instance" "gpu_instance" {
  count                         = 1 # can be as many as you want
  ami                           = "ami-0e1bed4f06a3b463d" # Ubuntu, since everyone loves it.
  instance_type                 = "g4dn.xlarge"
  subnet_id                     = element(aws_subnet.cluster_subnet.*.id, 1)
  vpc_security_group_ids        = [aws_security_group.cluster_sg.id]
  associate_public_ip_address   = true
  key_name                      = aws_key_pair.kp.key_name

  root_block_device {
    volume_type = "gp2"
    volume_size = 65
  }

  # Add an extra Name tag; provider-level default_tags will also apply
  tags = {
    Name = "gpu-instance-${count.index + 1}"
  }
}

output "gpu_instance_public_ip" {
  description = "Public IPs of the GPU instances"
  value       = [for instance in aws_instance.gpu_instance : instance.public_ip]
}
