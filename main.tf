provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  input_bucket_name  = var.input_bucket_name != "" ? var.input_bucket_name : "${local.name_prefix}-input-${data.aws_caller_identity.current.account_id}-${random_id.suffix.hex}"
  output_bucket_name = var.output_bucket_name != "" ? var.output_bucket_name : "${local.name_prefix}-output-${data.aws_caller_identity.current.account_id}-${random_id.suffix.hex}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "AWS Transcribe Call Analytics POC"
  }
}

# -----------------------------
# S3 Buckets
# -----------------------------

resource "aws_s3_bucket" "input" {
  bucket = local.input_bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket" "output" {
  bucket = local.output_bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "input" {
  bucket = aws_s3_bucket.input.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "output" {
  bucket = aws_s3_bucket.output.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "input" {
  bucket = aws_s3_bucket.input.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "output" {
  bucket = aws_s3_bucket.output.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "input" {
  bucket = aws_s3_bucket.input.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "output" {
  bucket = aws_s3_bucket.output.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# -----------------------------
# IAM Role for Amazon Transcribe
# -----------------------------

resource "aws_iam_role" "transcribe_data_access" {
  name = "${local.name_prefix}-transcribe-data-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "transcribe.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "transcribe_s3_access" {
  name        = "${local.name_prefix}-transcribe-s3-access-policy"
  description = "Allow Amazon Transcribe to read call recordings and write output JSON."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadInputAudio"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.input.arn}/*"
        ]
      },
      {
        Sid    = "ListInputBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.input.arn
        ]
      },
      {
        Sid    = "WriteOutput"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.output.arn}/*"
        ]
      },
      {
        Sid    = "ListOutputBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.output.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "transcribe_s3_access" {
  role       = aws_iam_role.transcribe_data_access.name
  policy_arn = aws_iam_policy.transcribe_s3_access.arn
}

# -----------------------------
# IAM Role for Lambda
# -----------------------------

resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "${local.name_prefix}-lambda-policy"
  description = "Allow Lambda to start Transcribe Call Analytics jobs and write logs."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid    = "StartCallAnalyticsJob"
        Effect = "Allow"
        Action = [
          "transcribe:StartCallAnalyticsJob",
          "transcribe:GetCallAnalyticsJob",
          "transcribe:ListCallAnalyticsJobs"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassTranscribeRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.transcribe_data_access.arn
      },
      {
        Sid    = "ReadInputBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.input.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# -----------------------------
# Lambda Package
# -----------------------------

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/start_call_analytics.py"
  output_path = "${path.module}/lambda/start_call_analytics.zip"
}

resource "aws_lambda_function" "start_call_analytics" {
  function_name = "${local.name_prefix}-start-call-analytics"
  role          = aws_iam_role.lambda.arn
  handler       = "start_call_analytics.lambda_handler"
  runtime       = "python3.11"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      OUTPUT_BUCKET              = aws_s3_bucket.output.bucket
      OUTPUT_PREFIX              = "call-analytics-output"
      TRANSCRIBE_DATA_ACCESS_ARN = aws_iam_role.transcribe_data_access.arn
      LANGUAGE_CODE              = var.language_code
      ENABLE_PII_REDACTION       = tostring(var.enable_pii_redaction)
      ENABLE_SUMMARY             = tostring(var.enable_summary)
      AUDIO_CHANNEL_TYPE         = var.audio_channel_type
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy
  ]
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.start_call_analytics.function_name}"
  retention_in_days = 14

  tags = local.common_tags
}

# -----------------------------
# S3 Event Trigger
# -----------------------------

resource "aws_lambda_permission" "allow_s3_input" {
  statement_id  = "AllowExecutionFromS3InputBucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_call_analytics.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input.arn
}

resource "aws_s3_bucket_notification" "input_notification" {
  bucket = aws_s3_bucket.input.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.start_call_analytics.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.recordings_prefix
    filter_suffix       = var.recordings_suffix
  }

  depends_on = [
    aws_lambda_permission.allow_s3_input
  ]
}
