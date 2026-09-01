import json
import os
import re
import boto3

SES_REGION = os.environ.get("SES_REGION", "us-east-2")
TO_EMAIL = os.environ["TO_EMAIL"]
FROM_EMAIL = os.environ["FROM_EMAIL"]

ses = boto3.client("ses", region_name=SES_REGION)

MAX_NAME_LENGTH = 100
MAX_SUBJECT_LENGTH = 150
MAX_MESSAGE_LENGTH = 2000
EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _response(400, {"error": "Invalid JSON"})

    name = (body.get("name") or "").strip()
    email = (body.get("email") or "").strip()
    subject = (body.get("subject") or "").strip()
    message = (body.get("message") or "").strip()

    if not all([name, email, subject, message]):
        return _response(400, {"error": "All fields are required"})
    if not EMAIL_RE.match(email):
        return _response(400, {"error": "Invalid email address"})
    if len(name) > MAX_NAME_LENGTH:
        return _response(400, {"error": f"Name too long (max {MAX_NAME_LENGTH} chars)"})
    if len(subject) > MAX_SUBJECT_LENGTH:
        return _response(400, {"error": f"Subject too long (max {MAX_SUBJECT_LENGTH} chars)"})
    if len(message) > MAX_MESSAGE_LENGTH:
        return _response(400, {"error": f"Message too long (max {MAX_MESSAGE_LENGTH} chars)"})

    body_text = (
        f"New message from your portfolio contact form:\n\n"
        f"Name: {name}\n"
        f"Email: {email}\n"
        f"Subject: {subject}\n\n"
        f"Message:\n{message}\n"
    )

    try:
        ses.send_email(
            Source=FROM_EMAIL,
            Destination={"ToAddresses": [TO_EMAIL]},
            Message={
                "Subject": {"Data": f"Portfolio Contact: {subject}"},
                "Body": {"Text": {"Data": body_text}},
            },
            ReplyToAddresses=[email],
        )
    except Exception as e:
        print(f"SES error: {e}")
        return _response(502, {"error": "Message could not be sent. Please try again later."})

    return _response(200, {"message": "Message sent successfully"})


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