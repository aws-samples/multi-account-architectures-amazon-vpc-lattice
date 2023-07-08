/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- distributed/service-account/main.tf ---

# AWS Account
data "aws_caller_identity" "account" {}

# ---------- VPC LATTICE SERVICE ----------
# VPC Lattice Module
module "vpc_lattice_service" {
  source  = "aws-ia/amazon-vpc-lattice-module/aws"
  version = "0.0.2"

  services = {
    lambdaservice = {
      name        = "lambda-service"
      auth_type   = "AWS_IAM"
      auth_policy = local.auth_policy

      listeners = {
        http_listener = {
          name     = "httplistener"
          port     = 80
          protocol = "HTTP"
          default_action_forward = {
            target_groups = {
              lambdatarget = { weight = 100 }
            }
          }
        }
      }
    }
  }

  target_groups = {
    lambdatarget = {
      type = "LAMBDA"
      targets = {
        lambdafunction = { id = aws_lambda_function.lambda.arn }
      }
    }
  }
}

# VPC Lattice service Auth Policy
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

# ---------- LAMBDA FUNCTION ----------
# AWS Lambda Function
resource "aws_lambda_function" "lambda" {
  function_name    = "lambda_function"
  filename         = "lambda_function.zip"
  source_code_hash = data.archive_file.python_lambda_package.output_base64sha256

  role    = aws_iam_role.lambda_role.arn
  runtime = "python3.10"
  handler = "lambda_function.lambda_handler"
}

data "archive_file" "python_lambda_package" {
  type        = "zip"
  source_file = "./lambda_function.py"
  output_path = "lambda_function.zip"
}

# IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "lambda-route53-role"
  path = "/"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_policy"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = data.aws_iam_policy_document.lambda_policy_document.json
}

data "aws_iam_policy_document" "lambda_policy_document" {
  statement {
    sid    = "LambdaLogging"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  name       = "lambda-logging-policy-attachment"
  roles      = [aws_iam_role.lambda_role.id]
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# ---------- AWS RAM - VPC LATTICE SERVICE ----------
# Resource Share
resource "aws_ram_resource_share" "resource_share" {
  name                      = "Amazon VPC Lattice service"
  allow_external_principals = true
}

# Principal Association
resource "aws_ram_principal_association" "principal_association" {
  principal          = var.consumer_aws_account
  resource_share_arn = aws_ram_resource_share.resource_share.arn
}

# Resource Association - VPC Lattice service
resource "aws_ram_resource_association" "lattice_service_share" {
  for_each = module.vpc_lattice_service.services

  resource_arn       = each.value.attributes.arn
  resource_share_arn = aws_ram_resource_share.resource_share.arn
}

# ---------- AWS SECRETS MANAGER ----------
# Secret: VPC Lattice services
resource "aws_secretsmanager_secret" "lattice_services" {
  name                    = "vpc_lattice_services"
  description             = "VPC Lattice Services information."
  kms_key_id              = aws_kms_key.secrets_key.arn
  policy                  = data.aws_iam_policy_document.secrets_resource_policy.json
  recovery_window_in_days = 0
}

# Generating map of VPC Lattice services - to send to consumer AWS Account
locals {
  vpc_lattice_services = {
    ram_share   = aws_ram_resource_share.resource_share.arn
    services_id = { for k, v in module.vpc_lattice_service.services : k => v.attributes.id }
  }
}

# Adding VPC Lattice services information
resource "aws_secretsmanager_secret_version" "vpc_lattice_service" {
  secret_id     = aws_secretsmanager_secret.lattice_services.id
  secret_string = jsonencode(local.vpc_lattice_services)
}

# Secrets resource policy - reading secret values
data "aws_iam_policy_document" "secrets_resource_policy" {
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

      values = [var.consumer_aws_account]
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