output "domain_controller_public_ip" {
  value = aws_instance.dc.public_ip
}