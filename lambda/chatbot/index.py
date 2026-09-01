import json
import os
import uuid
from datetime import datetime, timezone, timedelta

import boto3

dynamodb = boto3.resource("dynamodb")
bedrock = boto3.client("bedrock-runtime")

sessions_table = dynamodb.Table(os.environ["SESSIONS_TABLE"])
rate_limit_table = dynamodb.Table(os.environ["RATE_LIMIT_TABLE"])
DAILY_QUOTA = int(os.environ.get("DAILY_QUOTA", "100"))
MODEL_ID = os.environ["BEDROCK_MODEL_ID"]

SYSTEM_PROMPT = (
    "You are a helpful assistant on Vinny Maniscalco's portfolio website. "
    "Only answer questions about Vinny's resume, skills, and projects. "
    "Keep responses concise and friendly. If asked something unrelated, "
    "politely redirect to Vinny's background.\n\n"
    "Here is what you know about Vinny:\n"
    "- AWS Certified Cloud Practitioner\n"
    "- AWS Certified Solutions Architect - Associate (SAA-C03)\n"
    "- Built this portfolio site as the AWS Cloud Resume Challenge: "
    "S3 static hosting, CloudFront CDN, DynamoDB, Lambda, API Gateway, "
    "Terraform for infrastructure-as-code, and GitHub Actions for CI/CD\n"
    "- This chatbot itself runs on Bedrock (Claude), Lambda, and API Gateway\n"
    "- [Add: work history / past roles]\n"
    "- [Add: other technical skills, languages, tools]\n"
    "- [Add: education, other projects]\n"
)

MAX_MESSAGE_LENGTH = 500
MAX_HISTORY_MESSAGES = 10
SESSION_TTL_HOURS = 24


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON"})

    message = (body.get("message") or "").strip()
    session_id = body.get("session_id") or str(uuid.uuid4())

    if not message:
        return _response(400, {"error": "Message is required"})
    if len(message) > MAX_MESSAGE_LENGTH:
        return _response(400, {"error": f"Message too long (max {MAX_MESSAGE_LENGTH} chars)"})

    if not _check_and_increment_quota():
        return _response(429, {"error": "Daily quota exceeded, try again tomorrow"})

    history = _get_session_history(session_id)
    history.append({"role": "user", "content": message})
    trimmed = history[-MAX_HISTORY_MESSAGES:]

    try:
        reply = _call_bedrock(trimmed)
    except Exception as e:
        print(f"Bedrock error: {e}")
        return _response(502, {"error": "Chatbot is temporarily unavailable"})

    trimmed.append({"role": "assistant", "content": reply})
    _save_session_history(session_id, trimmed)

    return _response(200, {"session_id": session_id, "reply": reply})


def _check_and_increment_quota():
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    expires_at = int((datetime.now(timezone.utc) + timedelta(days=2)).timestamp())

    result = rate_limit_table.update_item(
        Key={"date": today},
        UpdateExpression="ADD request_count :inc SET expires_at = :ttl",
        ExpressionAttributeValues={":inc": 1, ":ttl": expires_at},
        ReturnValues="UPDATED_NEW",
    )
    return int(result["Attributes"]["request_count"]) <= DAILY_QUOTA


def _get_session_history(session_id):
    result = sessions_table.get_item(Key={"session_id": session_id})
    item = result.get("Item")
    return json.loads(item["messages"]) if item else []


def _save_session_history(session_id, history):
    expires_at = int((datetime.now(timezone.utc) + timedelta(hours=SESSION_TTL_HOURS)).timestamp())
    sessions_table.put_item(Item={
        "session_id": session_id,
        "messages": json.dumps(history),
        "expires_at": expires_at,
    })


def _call_bedrock(messages):
    bedrock_messages = [
        {"role": m["role"], "content": [{"text": m["content"]}]} for m in messages
    ]
    response = bedrock.converse(
        modelId=MODEL_ID,
        system=[{"text": SYSTEM_PROMPT}],
        messages=bedrock_messages,
        inferenceConfig={"maxTokens": 400, "temperature": 0.7},
    )
    return response["output"]["message"]["content"][0]["text"]


def _response(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type",
        },
        "body": json.dumps(body),
    }