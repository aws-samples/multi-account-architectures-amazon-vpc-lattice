/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- distributed/consumer-account/main.tf ---

# ---------- SECRETS MANAGER - OBTAINING LATTICE SERVICES ----------
data "aws_secretsmanager_secret" "lattice_services" {
  arn = "arn:aws:secretsmanager:${var.aws_region}:${var.service_aws_account}:secret:vpc_lattice_services"
}

data "aws_secretsmanager_secret_version" "lattice_services" {
  secret_id = data.aws_secretsmanager_secret.lattice_services.id
}

locals {
  lattice_services = nonsensitive(jsondecode(data.aws_secretsmanager_secret_version.lattice_services.secret_string))
}

# ---------- AWS RAM - ACCEPTING VPC LATTICE SERVICES ----------
resource "aws_ram_resource_share_accepter" "share_accepter" {
  share_arn = local.lattice_services.ram_share
}

# ---------- AMAZON VPC LATTICE ----------
# VPC Lattice service network Auth Policy
locals {
  auth_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "*"
        Effect    = "Allow"
        Principal = "*"
        Resource  = "*"
      }
    ]
  })
}

# Option 1: Using VPC Lattice module for all the VPC Lattice resources
module "vpc_lattice_all" {
  source  = "aws-ia/amazon-vpc-lattice-module/aws"
  version = "0.0.2"

  service_network = {
    name        = "vpc1-service-network"
    auth_type   = "AWS_IAM"
    auth_policy = local.auth_policy
  }

  vpc_associations = {
    vpc1 = {
      vpc_id             = module.vpc1.vpc_attributes.id
      security_group_ids = [aws_security_group.vpc1_lattice_sg.id]
    }
  }

  services = { for k, v in local.lattice_services.services_id : k => { identifier = v } }

  depends_on = [
    aws_ram_resource_share_accepter.share_accepter
  ]
}

module "vpc1" {
  source  = "aws-ia/vpc/aws"
  version = "4.3.0"

  name       = "vpc1"
  cidr_block = var.vpcs.vpc1.cidr_block
  az_count   = var.vpcs.vpc1.number_azs

  subnets = {
    workload  = { netmask = var.vpcs.vpc1.workload_subnet_netmask }
    endpoints = { netmask = var.vpcs.vpc1.endpoints_subnet_netmask }
  }
}

resource "aws_security_group" "vpc1_lattice_sg" {
  name        = local.security_groups.vpc_lattice.name
  description = local.security_groups.vpc_lattice.description
  vpc_id      = module.vpc1.vpc_attributes.id

  dynamic "ingress" {
    for_each = local.security_groups.vpc_lattice.ingress
    content {
      description = ingress.value.description
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = local.security_groups.vpc_lattice.egress
    content {
      description = egress.value.description
      from_port   = egress.value.from
      to_port     = egress.value.to
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }
}

# Option 2: Using VPC Lattice module for Service Network and Service Association, and VPC module for VPC Lattice VPC association
module "vpc_lattice_sn_service" {
  source  = "aws-ia/amazon-vpc-lattice-module/aws"
  version = "0.0.2"

  service_network = {
    name        = "vpc2-service-network"
    auth_type   = "AWS_IAM"
    auth_policy = local.auth_policy
  }

  services = { for k, v in local.lattice_services.services_id : k => { identifier = v } }

  depends_on = [
    aws_ram_resource_share_accepter.share_accepter
  ]
}

module "vpc2" {
  source  = "aws-ia/vpc/aws"
  version = "4.3.0"

  name       = "vpc2"
  cidr_block = var.vpcs.vpc2.cidr_block
  az_count   = var.vpcs.vpc2.number_azs

  vpc_lattice = {
    service_network_identifier = module.vpc_lattice_sn_service.service_network.id
    security_group_ids         = [aws_security_group.vpc2_lattice_sg.id]
  }

  subnets = {
    workload  = { netmask = var.vpcs.vpc2.workload_subnet_netmask }
    endpoints = { netmask = var.vpcs.vpc2.endpoints_subnet_netmask }
  }
}

resource "aws_security_group" "vpc2_lattice_sg" {
  name        = local.security_groups.vpc_lattice.name
  description = local.security_groups.vpc_lattice.description
  vpc_id      = module.vpc2.vpc_attributes.id

  dynamic "ingress" {
    for_each = local.security_groups.vpc_lattice.ingress
    content {
      description = ingress.value.description
      from_port   = ingress.value.from
      to_port     = ingress.value.to
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = local.security_groups.vpc_lattice.egress
    content {
      description = egress.value.description
      from_port   = egress.value.from
      to_port     = egress.value.to
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }
}

# ---------- VPC ENDPOINTS AND EC2 RESOURCES ----------
locals {
  vpcs = {
    vpc1 = module.vpc1
    vpc2 = module.vpc2
  }
}

# EC2 Instances
module "compute" {
  for_each = var.vpcs
  source   = "../../modules/compute"

  vpc_name             = each.key
  vpc_id               = local.vpcs[each.key].vpc_attributes.id
  vpc_subnets          = values({ for k, v in local.vpcs[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "workload" })
  number_azs           = each.value.number_azs
  instance_type        = each.value.instance_type
  ami_id               = data.aws_ami.amazon_linux.id
  ec2_security_group   = local.security_groups.instance
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.id

  depends_on = [module.endpoints]
}

# SSM VPC endpoints
module "endpoints" {
  for_each = var.vpcs
  source   = "../../modules/endpoints"

  vpc_name                 = each.key
  vpc_id                   = local.vpcs[each.key].vpc_attributes.id
  vpc_subnets              = values({ for k, v in local.vpcs[each.key].private_subnet_attributes_by_az : split("/", k)[1] => v.id if split("/", k)[0] == "endpoints" })
  endpoints_security_group = local.security_groups.endpoints
  endpoints_service_names  = local.endpoint_service_names
}

# ---------- IAM ROLE (EC2 INSTANCE) ----------
# IAM instance profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile_vpclattice_consumer"
  role = aws_iam_role.role_ec2.id
}

# IAM role
resource "aws_iam_role" "role_ec2" {
  name               = "ec2_ssm_role_vpclattice_consumer"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.policy_document.json
}

data "aws_iam_policy_document" "policy_document" {
  statement {
    sid     = "1"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

  }
}

# Policies Attachment to Role
resource "aws_iam_policy_attachment" "ssm_iam_role_policy_attachment" {
  name       = "ssm_iam_role_policy_attachment_consumer_vpclattice"
  roles      = [aws_iam_role.role_ec2.id]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
