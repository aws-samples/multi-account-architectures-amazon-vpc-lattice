
output "service_domain_name" {
  description = "VPC Lattice services domain name."
  value       = { for k, v in module.vpc_lattice_service.services : k => v.attributes.dns_entry[0].domain_name }
}