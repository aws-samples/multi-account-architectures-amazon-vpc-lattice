
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