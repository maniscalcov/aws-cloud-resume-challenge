resource "aws_dynamodb_table" "chatbot_sessions" {
  name         = "chatbot-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Project = "cloud-resume-challenge"
  }
}

resource "aws_dynamodb_table" "chatbot_rate_limit" {
  name         = "chatbot-rate-limit"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "date"

  attribute {
    name = "date"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Project = "cloud-resume-challenge"
  }
}
resource "aws_iam_role" "chatbot_lambda" {
  name = "chatbot-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = { Project = "cloud-resume-challenge" }
}

resource "aws_iam_role_policy" "chatbot_lambda_policy" {
  name = "chatbot-lambda-policy"
  role = aws_iam_role.chatbot_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "BedrockInvoke"
        Effect   = "Allow"
        Action   = "bedrock:InvokeModel"
        Resource = [
            "arn:aws:bedrock:us-east-2:584477830979:inference-profile/us.anthropic.claude-haiku-4-5-20251001-v1:0",
            "arn:aws:bedrock:*::foundation-model/anthropic.claude-haiku-4-5-20251001-v1:0"
        ]
      },
        {
        Sid    = "BedrockMarketplaceAccess"
        Effect = "Allow"
        Action = [
            "aws-marketplace:ViewSubscriptions",
            "aws-marketplace:Subscribe"
        ]
        Resource = "*"
        },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = [
          aws_dynamodb_table.chatbot_sessions.arn,
          aws_dynamodb_table.chatbot_rate_limit.arn
        ]
      },
      {
        Sid      = "CloudWatchLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:us-east-2:584477830979:log-group:/aws/lambda/chatbot:*"
      }
    ]
  })
}

data "archive_file" "chatbot_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/chatbot/index.py"
  output_path = "${path.module}/chatbot_lambda.zip"
}

resource "aws_lambda_function" "chatbot" {
  function_name    = "chatbot"
  role              = aws_iam_role.chatbot_lambda.arn
  handler           = "index.handler"
  runtime           = "python3.13"
  filename          = data.archive_file.chatbot_lambda_zip.output_path
  source_code_hash  = data.archive_file.chatbot_lambda_zip.output_base64sha256
  timeout           = 15
  memory_size       = 256

  environment {
    variables = {
      SESSIONS_TABLE   = aws_dynamodb_table.chatbot_sessions.name
      RATE_LIMIT_TABLE = aws_dynamodb_table.chatbot_rate_limit.name
      DAILY_QUOTA      = "100"
      BEDROCK_MODEL_ID = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
    }
  }

  tags = { Project = "cloud-resume-challenge" }
}

resource "aws_apigatewayv2_api" "chatbot" {
  name          = "chatbot-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_credentials = false
    allow_methods     = ["POST"]
    allow_headers     = ["Content-Type"]
    allow_origins     = ["http://127.0.0.1:5500", "https://d3v6sllvp0c9mk.cloudfront.net"]
  }

  tags = { Project = "cloud-resume-challenge" }
}

resource "aws_apigatewayv2_integration" "chatbot" {
  api_id                 = aws_apigatewayv2_api.chatbot.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.chatbot.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "chatbot" {
  api_id    = aws_apigatewayv2_api.chatbot.id
  route_key = "POST /chat"
  target    = "integrations/${aws_apigatewayv2_integration.chatbot.id}"
}

resource "aws_apigatewayv2_stage" "chatbot" {
  api_id      = aws_apigatewayv2_api.chatbot.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 5
    throttling_rate_limit  = 2
  }

  tags = { Project = "cloud-resume-challenge" }
}

resource "aws_lambda_permission" "apigateway_chatbot" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chatbot.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chatbot.execution_arn}/*/*"
}

output "chatbot_api_endpoint" {
  value = "${aws_apigatewayv2_api.chatbot.api_endpoint}/chat"
}