# ── Contact form Lambda ──────────────────────────────────────────
# Reuses the existing "chatbot" API Gateway (aws_apigatewayv2_api.chatbot)
# since it's already in us-east-2 with CORS configured — adding a new
# route to it is simpler than standing up a second API.

resource "aws_iam_role" "contact_lambda" {
  name     = "contact-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "contact_lambda_basic" {
  role       = aws_iam_role.contact_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "contact_lambda_ses" {
  name     = "contact-lambda-ses-send"
  role     = aws_iam_role.contact_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SESSendEmail"
      Effect   = "Allow"
      Action   = ["ses:SendEmail", "ses:SendRawEmail"]
      Resource = "*"
    }]
  })
}

resource "aws_lambda_function" "contact" {
  function_name = "contact-form"
  role          = aws_iam_role.contact_lambda.arn
  handler       = "index.handler"
  runtime       = "python3.13" # match whatever runtime your chatbot Lambda uses if different
  filename      = "contact_lambda.zip"
  source_code_hash = filebase64sha256("contact_lambda.zip")
  timeout       = 10

  environment {
    variables = {
      SES_REGION = "us-east-2"
      TO_EMAIL   = "vjmaniscalco@outlook.com"
      FROM_EMAIL = "vjmaniscalco@outlook.com"
    }
  }

  tags = { Project = "cloud-resume-challenge" }
}

resource "aws_lambda_permission" "apigw_contact" {
  statement_id  = "AllowAPIGatewayInvokeContact"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chatbot.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "contact" {
  api_id                 = aws_apigatewayv2_api.chatbot.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.contact.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "contact" {
  api_id    = aws_apigatewayv2_api.chatbot.id
  route_key = "POST /contact"
  target    = "integrations/${aws_apigatewayv2_integration.contact.id}"
}
