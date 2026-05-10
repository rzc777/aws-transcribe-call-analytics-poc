variable "aws_region" {
  description = "AWS region to deploy resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix."
  type        = string
  default     = "transcribe-poc"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "poc"
}

variable "input_bucket_name" {
  description = "S3 bucket for call recordings. Leave empty to auto-generate."
  type        = string
  default     = ""
}

variable "output_bucket_name" {
  description = "S3 bucket for Transcribe output. Leave empty to auto-generate."
  type        = string
  default     = ""
}

variable "language_code" {
  description = "Transcribe language code, for example en-US or zh-CN."
  type        = string
  default     = "en-US"
}

variable "enable_pii_redaction" {
  description = "Enable PII redaction in Call Analytics job."
  type        = bool
  default     = true
}

variable "enable_summary" {
  description = "Enable abstractive call summary."
  type        = bool
  default     = true
}

variable "audio_channel_type" {
  description = "dual_channel or single_channel. For typical call center stereo recording use dual_channel."
  type        = string
  default     = "dual_channel"

  validation {
    condition     = contains(["dual_channel", "single_channel"], var.audio_channel_type)
    error_message = "audio_channel_type must be dual_channel or single_channel."
  }
}

variable "recordings_prefix" {
  description = "S3 prefix to watch for new call recordings."
  type        = string
  default     = "recordings/"
}

variable "recordings_suffix" {
  description = "S3 object suffix to trigger Lambda. Keep one suffix for fastest POC."
  type        = string
  default     = ".wav"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 60
}

variable "lambda_memory_size" {
  description = "Lambda memory size."
  type        = number
  default     = 256
}
