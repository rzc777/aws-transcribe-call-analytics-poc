output "instance_public_ip" {
  description = "Public IP of the WireGuard VPN server."
  value       = aws_eip.wireguard.public_ip
}

output "wireguard_ui_url" {
  description = "wg-easy web UI URL."
  value       = "http://${aws_eip.wireguard.public_ip}:${var.web_ui_port}"
}

output "ssh_command" {
  description = "SSH command for the EC2 instance."
  value       = "ssh ubuntu@${aws_eip.wireguard.public_ip}"
}
