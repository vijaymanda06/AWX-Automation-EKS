packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "project_name" {
  type    = string
  default = "zerotrust"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "ubuntu_golden" {
  ami_name      = "${var.project_name}-golden-ami-${local.timestamp}"
  instance_type = var.instance_type
  region        = var.region

  # Use Ubuntu 24.04 LTS (Noble Numbat)
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical
  }

  ssh_username = "ubuntu"

  # Encrypted root volume
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name        = "${var.project_name}-golden-ami"
    Environment = "production"
    ManagedBy   = "Packer"
    OS          = "Ubuntu 24.04"
  }
}

build {
  name = "golden-ami"
  sources = [
    "source.amazon-ebs.ubuntu_golden"
  ]

  # Provision using the setup script
  provisioner "shell" {
    script          = "setup-scripts/install.sh"
    execute_command = "echo 'packer' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
  }

  # Generate manifest file so Terraform can read the created AMI ID later
  post-processor "manifest" {
    output     = "manifest.json"
    strip_path = true
  }
}
