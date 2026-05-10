output "input_bucket_name" {
  description = "Upload call recordings to this bucket under recordings/."
  value       = aws_s3_bucket.input.bucket
}

output "output_bucket_name" {
  description = "Transcribe Call Analytics output bucket."
  value       = aws_s3_bucket.output.bucket
}

output "lambda_function_name" {
  description = "Lambda function that starts Call Analytics jobs."
  value       = aws_lambda_function.start_call_analytics.function_name
}

output "transcribe_data_access_role_arn" {
  description = "IAM role used by Amazon Transcribe to access S3."
  value       = aws_iam_role.transcribe_data_access.arn
}

output "test_upload_command" {
  description = "Upload a wav file to trigger the POC."
  value       = "aws s3 cp sample.wav s3://${aws_s3_bucket.input.bucket}/${var.recordings_prefix}sample.wav"
}

output "output_location" {
  description = "Where Transcribe Call Analytics JSON output will be stored."
  value       = "s3://${aws_s3_bucket.output.bucket}/call-analytics-output/"
}
