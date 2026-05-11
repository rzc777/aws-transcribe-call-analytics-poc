provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu_arm64" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_eip" "wireguard" {
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }
}

resource "aws_security_group" "wireguard" {
  name_prefix = "${var.project_name}-"
  description = "Pure WireGuard VPN security group"

  ingress {
    description = "WireGuard UDP"
    from_port   = var.wireguard_port
    to_port     = var.wireguard_port
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

resource "aws_iam_role" "ssm" {
  name = "${var.project_name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.project_name}-ssm-role"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "eip_reassociate" {
  name = "${var.project_name}-eip-reassociate"
  role = aws_iam_role.ssm.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:AssociateAddress",
          "ec2:DescribeAddresses",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.project_name}-ssm-profile"
  role = aws_iam_role.ssm.name
}

resource "aws_instance" "wireguard" {
  ami                         = data.aws_ami.ubuntu_arm64.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.wireguard.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  associate_public_ip_address = true
  source_dest_check           = false
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    aws_region           = var.aws_region
    eip_allocation_id    = aws_eip.wireguard.id
    wg_host              = aws_eip.wireguard.public_ip
    wg_dns               = var.wg_dns
    wg_cidr              = var.wg_cidr
    wg_server_ip         = var.wg_server_ip
    wg_client_ip         = var.wg_client_ip
    wireguard_port       = var.wireguard_port
    client_mtu           = var.client_mtu
    persistent_keepalive = var.persistent_keepalive
  })

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name    = "${var.project_name}-ec2"
    Project = var.project_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.ssm_managed,
    aws_iam_role_policy.eip_reassociate
  ]
}

resource "aws_eip_association" "wireguard" {
  instance_id   = aws_instance.wireguard.id
  allocation_id = aws_eip.wireguard.id
}
