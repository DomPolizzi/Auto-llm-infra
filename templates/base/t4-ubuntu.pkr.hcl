packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "${UUID_HERE}" # uuidgen
  instance_type = "g4dn.xlarge"
  region        = "us-east-1"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"] # Canonical
    most_recent = true
  }
  ssh_username = "ubuntu"

  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 50
    volume_type           = "gp2"
    delete_on_termination = true
  }
}

build {
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "shell" {
    inline = [
      "sudo apt update",
      "sudo apt-get update",
      "sudo apt install curl ca-certificates apt-transport-https debconf-doc gnupg -y",
      "DEBIAN_FRONTEND=noninteractive sudo apt upgrade -yq",
      "DEBIAN_FRONTEND=noninteractive sudo apt install vim git gcc make libseccomp-dev bison build-essential zip clang python3-venv cmake -yq",
      "mkdir ~/workspace/"
    ]
  }

  provisioner "file" {
    source      = "docker.sh"
    destination = "/home/ubuntu/docker.sh"
  }

  provisioner "shell" {
    inline = [
      "bash /home/ubuntu/docker.sh"
    ]
  }

  provisioner "file" {
    source      = "cuda.sh"
    destination = "/home/ubuntu/cuda.sh"
  }

  provisioner "shell" {
    inline = [
      "bash /home/ubuntu/cuda.sh"
    ]
  }

  provisioner "file" {
    source      = "container-toolkit.sh"
    destination = "/home/ubuntu/container-toolkit.sh"
  }

  provisioner "shell" {
    inline = [
      "bash /home/ubuntu/container-toolkit.sh"
    ]
  }
}
