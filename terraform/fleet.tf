# --- IAM Role for EC2 Fleet (SSM Access) ---

resource "aws_iam_role" "fleet" {
  name = "${var.project_name}-fleet-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-fleet-role"
  }
}

# Attach the AWS managed policy to allow SSM Session Manager
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.fleet.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "fleet" {
  name = "${var.project_name}-fleet-profile"
  role = aws_iam_role.fleet.name
}

# --- Zero-Trust Security Group ---

resource "aws_security_group" "fleet" {
  name        = "${var.project_name}-fleet-sg"
  description = "Zero-Trust SG for EC2 Fleet (No Inbound)"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.project_name}-fleet-sg"
  }
}

# EGRESS ONLY: Allow HTTPS to VPC Endpoints (Zero-Trust)
resource "aws_vpc_security_group_egress_rule" "fleet_egress" {
  security_group_id            = aws_security_group.fleet.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.vpc_endpoints_sg.id
}
# Notice: There are NO ingress rules defined. No SSH, no HTTP.

# --- Read the Golden AMI ID created by Packer ---

data "local_file" "packer_manifest" {
  filename = "${path.module}/../packer/manifest.json"
}

locals {
  packer_data   = jsondecode(data.local_file.packer_manifest.content)
  golden_builds = [for b in local.packer_data.builds : b if b.name == "ubuntu_golden"]
  golden_build  = local.golden_builds[length(local.golden_builds) - 1]
  # Packer manifest artifact format: "us-east-1:ami-0abcd12345"
  golden_ami_id = split(":", local.golden_build.artifact_id)[1]
}

# --- EC2 Instances (Fleet) ---

resource "aws_instance" "fleet" {
  count = 2

  ami           = local.golden_ami_id
  instance_type = "t3.small"
  subnet_id     = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]

  iam_instance_profile        = aws_iam_instance_profile.fleet.name
  vpc_security_group_ids      = [aws_security_group.fleet.id]
  associate_public_ip_address = false

  # Enforce IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${var.project_name}-fleet-node-${count.index + 1}"
    Role = "web-fleet" # This tag is used by AWX dynamic inventory
  }
}

# --- Output the Instance IDs ---

output "fleet_instance_ids" {
  description = "IDs of the fleet EC2 instances"
  value       = aws_instance.fleet[*].id
}
