<!-- BEGIN_TF_DOCS -->
# Consumer AWS Account

## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_compute"></a> [compute](#module\_compute) | ../../modules/compute | n/a |
| <a name="module_endpoints"></a> [endpoints](#module\_endpoints) | ../../modules/endpoints | n/a |
| <a name="module_vpc1"></a> [vpc1](#module\_vpc1) | aws-ia/vpc/aws | 4.3.0 |
| <a name="module_vpc2"></a> [vpc2](#module\_vpc2) | aws-ia/vpc/aws | 4.3.0 |
| <a name="module_vpc_lattice_vpc_association"></a> [vpc\_lattice\_vpc\_association](#module\_vpc\_lattice\_vpc\_association) | aws-ia/amazon-vpc-lattice-module/aws | 0.0.2 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.ec2_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy_attachment.ssm_iam_role_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy_attachment) | resource |
| [aws_iam_role.role_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_ram_resource_share_accepter.share_accepter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share_accepter) | resource |
| [aws_security_group.vpc1_lattice_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.vpc2_lattice_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ami.amazon_linux](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_iam_policy_document.policy_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_secretsmanager_secret.service_network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.service_network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_central_aws_account"></a> [central\_aws\_account](#input\_central\_aws\_account) | AWS Account - Central. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS Region. | `string` | `"eu-west-1"` | no |
| <a name="input_vpcs"></a> [vpcs](#input\_vpcs) | VPCs to create. | `any` | <pre>{<br>  "vpc1": {<br>    "cidr_block": "10.0.0.0/24",<br>    "endpoints_subnet_netmask": 28,<br>    "instance_type": "t2.micro",<br>    "number_azs": 2,<br>    "vpc_lattice_module": true,<br>    "workload_subnet_netmask": 28<br>  },<br>  "vpc2": {<br>    "cidr_block": "10.0.0.0/24",<br>    "endpoints_subnet_netmask": 28,<br>    "instance_type": "t2.micro",<br>    "number_azs": 2,<br>    "vpc_lattice_module": true,<br>    "workload_subnet_netmask": 28<br>  }<br>}</pre> | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->