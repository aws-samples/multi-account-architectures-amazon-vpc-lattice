/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- distributed/service-account/variables.tf ---

variable "aws_region" {
  type        = string
  description = "AWS Region."

  default = "eu-west-1"
}

variable "consumer_aws_account" {
  type        = string
  description = "AWS Account - Consumer."
}