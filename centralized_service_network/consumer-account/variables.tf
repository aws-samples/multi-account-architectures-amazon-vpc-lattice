/* Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 SPDX-License-Identifier: MIT-0 */

# --- centralized_service_network/consumer-account/variables.tf ---

variable "aws_region" {
  type        = string
  description = "AWS Region."

  default = "eu-west-1"
}

variable "central_aws_account" {
  type        = string
  description = "AWS Account - Central."
}

variable "vpcs" {
  type        = any
  description = "VPCs to create."

  default = {
    vpc1 = {
      vpc_lattice_module       = true
      cidr_block               = "10.0.0.0/24"
      number_azs               = 2
      workload_subnet_netmask  = 28
      endpoints_subnet_netmask = 28
      instance_type            = "t2.micro"
    }
    vpc2 = {
      vpc_lattice_module       = true
      cidr_block               = "10.0.0.0/24"
      number_azs               = 2
      workload_subnet_netmask  = 28
      endpoints_subnet_netmask = 28
      instance_type            = "t2.micro"
    }
  }
}