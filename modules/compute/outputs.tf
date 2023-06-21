
output "instances_created" {
  value       = aws_instance.ec2_instance
  description = "List of instances created."
}