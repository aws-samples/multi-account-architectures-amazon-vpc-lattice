/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- modules/endpoints/main.tf ---

# VPC ENDPOINTS
resource "aws_vpc_endpoint" "endpoint" {
  for_each = var.endpoints_service_names

  vpc_id              = var.vpc_id
  service_name        = each.value.name
  vpc_endpoint_type   = each.value.type
  subnet_ids          = var.vpc_subnets
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  private_dns_enabled = each.value.private_dns
}

# Security Group
resource "aws_security_group" "endpoints_sg" {
  name        = var.endpoints_security_group.name
  description = var.endpoints_security_group.description
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.endpoints_security_group.ingress
    content {
      description = ingress.value.description
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = var.endpoints_security_group.egress
    content {
      description = egress.value.description
      from_port   = egress.value.from
      to_port     = egress.value.to
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }
}