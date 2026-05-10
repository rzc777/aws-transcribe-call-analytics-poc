import json
import os
import uuid
import urllib.parse

import boto3
from botocore.exceptions import ClientError

transcribe = boto3.client("transcribe")


def str_to_bool(value: str) -> bool:
    return str(value).lower() in ["true", "1", "yes", "y"]


def lambda_handler(event, context):
    print("Received event:")
    print(json.dumps(event))

    output_bucket = os.environ["OUTPUT_BUCKET"]
    output_prefix = os.environ.get("OUTPUT_PREFIX", "call-analytics-output")
    data_access_role_arn = os.environ["TRANSCRIBE_DATA_ACCESS_ARN"]

    language_code = os.environ.get("LANGUAGE_CODE", "en-US")
    enable_pii_redaction = str_to_bool(os.environ.get("ENABLE_PII_REDACTION", "true"))
    enable_summary = str_to_bool(os.environ.get("ENABLE_SUMMARY", "true"))
    audio_channel_type = os.environ.get("AUDIO_CHANNEL_TYPE", "dual_channel")

    results = []

    for record in event.get("Records", []):
        input_bucket = record["s3"]["bucket"]["name"]
        object_key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        allowed_extensions = (".wav", ".mp3", ".flac", ".ogg", ".amr", ".webm")
        if not object_key.lower().endswith(allowed_extensions):
            print(f"Skipping unsupported file: {object_key}")
            continue

        clean_key = (
            object_key
            .replace("/", "-")
            .replace("_", "-")
            .replace(".", "-")
        )

        job_name = f"ca-{clean_key[:80]}-{uuid.uuid4().hex[:8]}"
        media_uri = f"s3://{input_bucket}/{object_key}"
        output_location = f"s3://{output_bucket}/{output_prefix}/"

        request = {
            "CallAnalyticsJobName": job_name,
            "Media": {
                "MediaFileUri": media_uri
            },
            "OutputLocation": output_location,
            "DataAccessRoleArn": data_access_role_arn,
            "LanguageCode": language_code,
            "Settings": {}
        }

        if audio_channel_type == "dual_channel":
            request["ChannelDefinitions"] = [
                {
                    "ChannelId": 0,
                    "ParticipantRole": "AGENT"
                },
                {
                    "ChannelId": 1,
                    "ParticipantRole": "CUSTOMER"
                }
            ]

        if enable_pii_redaction:
            request["Settings"]["ContentRedaction"] = {
                "RedactionType": "PII",
                "RedactionOutput": "redacted_and_unredacted"
            }

        if enable_summary:
            request["Settings"]["Summarization"] = {
                "GenerateAbstractiveSummary": True
            }

        if not request["Settings"]:
            del request["Settings"]

        print("Starting Call Analytics job:")
        print(json.dumps(request))

        try:
            response = transcribe.start_call_analytics_job(**request)
            print("StartCallAnalyticsJob response:")
            print(json.dumps(response, default=str))

            results.append({
                "input": media_uri,
                "job_name": job_name,
                "status": "STARTED",
                "output_location": output_location
            })

        except ClientError as e:
            print(f"Failed to start job for {media_uri}")
            print(e)

            results.append({
                "input": media_uri,
                "job_name": job_name,
                "status": "FAILED",
                "error": str(e)
            })

    return {
        "statusCode": 200,
        "body": json.dumps(results)
    }
