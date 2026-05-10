# AWS Transcribe Call Analytics POC

A fast Terraform POC for post-call analytics with Amazon Transcribe Call Analytics.

## What this deploys

```text
S3 input bucket
  -> S3 ObjectCreated event
  -> Lambda
  -> Amazon Transcribe Call Analytics job
  -> S3 output bucket
```

## Files

```text
.
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── terraform.tfvars.example
└── lambda/
    └── start_call_analytics.py
```

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured locally
- AWS account permission to create S3, IAM, Lambda, CloudWatch Logs, and Transcribe resources
- A test audio file, ideally `.wav`

## Deploy

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Upload test call recording

After deployment:

```bash
terraform output -raw test_upload_command
```

Or manually:

```bash
aws s3 cp sample.wav s3://$(terraform output -raw input_bucket_name)/recordings/sample.wav
```

## Check Lambda logs

```bash
aws logs tail /aws/lambda/$(terraform output -raw lambda_function_name) --follow
```

## Check Transcribe output

```bash
aws s3 ls s3://$(terraform output -raw output_bucket_name)/call-analytics-output/ --recursive
```

## Language

Default is English:

```hcl
language_code = "en-US"
```

For Mandarin Chinese:

```hcl
language_code = "zh-CN"
```

## Audio channel mode

Default:

```hcl
audio_channel_type = "dual_channel"
```

Use this when your call center recording is stereo:

```text
channel 0 = agent
channel 1 = customer
```

For single-channel mixed audio:

```hcl
audio_channel_type = "single_channel"
```

## Important notes

- This POC triggers only files matching `recordings/*.wav` by default.
- To test mp3, change:

```hcl
recordings_suffix = ".mp3"
```

- Transcribe is asynchronous, so Lambda success only means the job started.
- Check the job status with:

```bash
aws transcribe get-call-analytics-job --call-analytics-job-name <job-name>
```

Job names are printed in Lambda logs.

## Cleanup

```bash
terraform destroy
```

If S3 buckets contain files, empty them first.
