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
  description = "WireGuard UDP port."
  type        = number
  default     = 51820
}

variable "web_ui_port" {
  description = "wg-easy web UI TCP port."
  type        = number
  default     = 51821
}

variable "wg_default_dns" {
  description = "DNS server pushed to VPN clients."
  type        = string
  default     = "1.1.1.1"
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to access SSH and wg-easy web UI. For POC only, 0.0.0.0/0 is convenient but less secure."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "wg_easy_password" {
  description = "Password for wg-easy web UI. Pass with TF_VAR_wg_easy_password."
  type        = string
  sensitive   = true
}
