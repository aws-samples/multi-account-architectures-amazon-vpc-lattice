
variable "aws_region" {
  type        = string
  description = "AWS Region."

  default = "eu-west-1"
}

variable "central_aws_account" {
  type        = string
  description = "AWS Account - Central."
}