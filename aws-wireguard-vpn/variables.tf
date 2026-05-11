variable "aws_region" {
  description = "AWS region for the VPN server."
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name prefix."
  type        = string
  default     = "wireguard-vpn"
}

variable "instance_type" {
  description = "EC2 instance type. t4g.nano is the lowest-cost recommended option."
  type        = string
  default     = "t4g.nano"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB."
  type        = number
  default     = 20
}

variable "wireguard_port" {
  description = "WireGuard UDP port. UDP 443 is used by default for better NAT/ISP compatibility."
  type        = number
  default     = 443
}

variable "wg_dns" {
  description = "DNS server pushed to VPN clients."
  type        = string
  default     = "1.1.1.1"
}

variable "wg_cidr" {
  description = "WireGuard VPN CIDR."
  type        = string
  default     = "10.8.0.0/24"
}

variable "wg_server_ip" {
  description = "WireGuard server tunnel IP with CIDR."
  type        = string
  default     = "10.8.0.1/24"
}

variable "wg_client_ip" {
  description = "WireGuard Windows client tunnel IP with CIDR."
  type        = string
  default     = "10.8.0.2/32"
}
