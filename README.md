# Multi-AWS Account Architectures with Amazon VPC Lattice (Terraform)

In this repository, you will show how to deploy [Amazon VPC Lattice](https://docs.aws.amazon.com/vpc-lattice/latest/ug/what-is-vpc-lattice.html) resources in multi-AWS Account environments - using Terraform as Infrastructure as Code (IaC) framework. VPC Lattice is a fully managed application networking service that you use to connect, secure, and monitor the services for your application across multiple accounts and virtual private clouds (VPC).

When discussing multi-Account environments, you can have several deployment models to follow. We are covering the two most common ones: centralized service networks, and distributed service networks owned by consumer AWS Accounts. For more information about the architectures (and the implementation code), move to the corresponding folder:

* [Centralized VPC Lattice service network](./centralized_service_network/).

![Centralized diagram](./images/centralized.png)

* [Distributed VPC Lattice service networks](./distributed/).

![Distributed diagram](./images/distributed.png)

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

