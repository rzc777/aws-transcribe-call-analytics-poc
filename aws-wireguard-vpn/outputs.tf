output "instance_public_ip" {
  description = "Public IP of the WireGuard server"
  value       = aws_eip.wireguard.public_ip
}

output "wireguard_endpoint" {
  description = "WireGuard endpoint for the Windows client"
  value       = "${aws_eip.wireguard.public_ip}:${var.wireguard_port}"
}

output "instance_id" {
  description = "EC2 instance ID for SSM Session Manager"
  value       = aws_instance.wireguard.id
}

output "client_config_path" {
  description = "Path of the generated Windows client config on the EC2 instance"
  value       = "/opt/wireguard/windows-client.conf"
}
