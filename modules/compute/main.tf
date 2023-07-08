/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- modules/compute/main.tf ---

# EC2 instances
resource "aws_instance" "ec2_instance" {
  count = var.number_azs

  ami                         = var.ami_id
  associate_public_ip_address = false
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.instance_sg.id]
  subnet_id                   = var.vpc_subnets[count.index]
  iam_instance_profile        = var.iam_instance_profile

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "${var.vpc_name}-instance-${count.index + 1}"
  }
}

# Security Group
resource "aws_security_group" "instance_sg" {
  name        = var.ec2_security_group.name
  description = var.ec2_security_group.description
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ec2_security_group.ingress
    content {
      description = ingress.value.description
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = var.ec2_security_group.egress
    content {
      description = egress.value.description
      from_port   = egress.value.from
      to_port     = egress.value.to
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }
}