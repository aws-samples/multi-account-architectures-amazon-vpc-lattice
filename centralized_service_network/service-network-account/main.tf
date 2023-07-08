/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- centralized_service_network/service-network-account/main.tf ---

# AWS Account
data "aws_caller_identity" "account" {}

# ---------- AMAZON VPC LATTICE (SERVICE NETWORK) ----------
# VPC Lattice Module
module "vpclattice_service_network" {
  source  = "aws-ia/amazon-vpc-lattice-module/aws"
  version = "0.0.2"

  service_network = {
    name        = "centralized-service-network"
    auth_type   = "AWS_IAM"
    auth_policy = local.auth_policy
  }

  services = { for k, v in local.lattice_services.services_id : k => { identifier = v } }

  depends_on = [aws_ram_resource_share_accepter.share_accepter]
}

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

# ---------- AWS SECRETS MANAGER ----------
# Secret: Service Network
resource "aws_secretsmanager_secret" "service_network" {
  name                    = "service_network"
  description             = "VPC Lattice Service Network ARN"
  kms_key_id              = aws_kms_key.secrets_key.arn
  policy                  = data.aws_iam_policy_document.secrets_resource_policy_reading.json
  recovery_window_in_days = 0
}

locals {
  service_network = {
    id        = module.vpclattice_service_network.service_network.id
    ram_share = aws_ram_resource_share.resource_share.arn
  }
}

resource "aws_secretsmanager_secret_version" "service_network" {
  secret_id     = aws_secretsmanager_secret.service_network.id
  secret_string = jsonencode(local.service_network)
}

# Secret: Services
resource "aws_secretsmanager_secret" "lattice_services" {
  name                    = "vpclattice_services"
  description             = "VPC Lattice Services information."
  kms_key_id              = aws_kms_key.secrets_key.arn
  policy                  = data.aws_iam_policy_document.secrets_resource_policy_writing.json
  recovery_window_in_days = 0
}

# Obtaining Lattice Services information (from Service Provider AWS Accounts)
data "aws_secretsmanager_secret_version" "lattice_services" {
  secret_id = aws_secretsmanager_secret.lattice_services.id
}

locals {
  lattice_services = nonsensitive(jsondecode(data.aws_secretsmanager_secret_version.lattice_services.secret_string))
}

# Secrets resource policy - reading secret values
data "aws_iam_policy_document" "secrets_resource_policy_reading" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy"
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalAccount"

      values = [var.consumer_aws_account]
    }
  }
}

# Secrets resource policy - writing secret values
data "aws_iam_policy_document" "secrets_resource_policy_writing" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetResourcePolicy"
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalAccount"

      values = [var.service_aws_account]
    }
  }
}

# KMS Key to encrypt the secrets
resource "aws_kms_key" "secrets_key" {
  description             = "KMS Secrets Key - Central Account."
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.policy_kms_document.json

  tags = {
    Name = "kms-key-servicenetwork-account"
  }
}

# KMS Policy
data "aws_iam_policy_document" "policy_kms_document" {
  statement {
    sid    = "Enable AWS Secrets Manager secrets decryption."
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:*"
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"

      values = ["secretsmanager.${var.aws_region}.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:SecretARN"

      values = ["arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.account.id}:secret:*"]
    }
    condition {
      test     = "StringLike"
      variable = "aws:PrincipalAccount"

      values = [var.consumer_aws_account, var.service_aws_account]
    }
  }

  statement {
    sid       = "Enable IAM User Permissions"
    actions   = ["kms:*"]
    resources = ["arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.account.id}:*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.account.id}:root"]
    }
  }
}

# ---------- AWS RAM ----------
# Resource Share
resource "aws_ram_resource_share" "resource_share" {
  name                      = "Amazon VPC Lattice service network"
  allow_external_principals = true
}

# Principal Association
resource "aws_ram_principal_association" "principal_association" {
  principal          = var.consumer_aws_account
  resource_share_arn = aws_ram_resource_share.resource_share.arn
}

# Resource Association - VPC Lattice service network
resource "aws_ram_resource_association" "lattice_service_network_share" {
  resource_arn       = module.vpclattice_service_network.service_network.arn
  resource_share_arn = aws_ram_resource_share.resource_share.arn
}

# Accepting VPC Lattice services from Service Provider AWS Account
resource "aws_ram_resource_share_accepter" "share_accepter" {
  share_arn = local.lattice_services.ram_share
}