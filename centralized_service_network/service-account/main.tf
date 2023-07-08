/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- centralized_service_network/service-account/main.tf ---

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

# Generating map of VPC Lattice services - to send to Service Network AWS Account
locals {
  vpc_lattice_services = {
    ram_share   = aws_ram_resource_share.resource_share.arn
    services_id = { for k, v in module.vpc_lattice_service.services : k => v.attributes.id }
  }
}

# Getting the Secrets Manager secret and add the VPC Lattice service information
data "aws_secretsmanager_secret" "vpc_lattice_services" {
  arn = "arn:aws:secretsmanager:${var.aws_region}:${var.central_aws_account}:secret:vpclattice_services"
}

resource "aws_secretsmanager_secret_version" "vpc_lattice_service" {
  secret_id     = data.aws_secretsmanager_secret.vpc_lattice_services.id
  secret_string = jsonencode(local.vpc_lattice_services)
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
  principal          = var.central_aws_account
  resource_share_arn = aws_ram_resource_share.resource_share.arn
}

# Resource Association - VPC Lattice service
resource "aws_ram_resource_association" "lattice_service_share" {
  for_each = module.vpc_lattice_service.services

  resource_arn       = each.value.attributes.arn
  resource_share_arn = aws_ram_resource_share.resource_share.arn
}