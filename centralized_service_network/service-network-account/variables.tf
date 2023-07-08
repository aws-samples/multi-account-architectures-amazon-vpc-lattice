/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- centralized_service_network/service-network-account/variables.tf ---

variable "aws_region" {
  type        = string
  description = "AWS Region."

  default = "eu-west-1"
}

variable "consumer_aws_account" {
  type        = number
  description = "AWS Account ID - Consumer."
}

variable "service_aws_account" {
  type        = number
  description = "AWS Account ID - Service Provider."
}