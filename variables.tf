variable "aws_region" { default = "us-east-1" }
variable "project_name" { default = "transcribe-poc" }
variable "environment" { default = "poc" }
variable "language_code" { default = "en-US" }
variable "enable_pii_redaction" { default = true }
variable "enable_summary" { default = true }
variable "audio_channel_type" { default = "dual_channel" }
