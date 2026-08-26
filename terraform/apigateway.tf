resource "aws_apigatewayv2_api" "visitor_counter" {
  provider      = aws.us_east_1
  name          = "cloud-resume-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_credentials = false
    allow_methods     = ["GET"]
    allow_origins     = ["https://d3v6sllvp0c9mk.cloudfront.net"]
  }
}

resource "aws_apigatewayv2_integration" "visitor_counter" {
  provider                = aws.us_east_1
  api_id                  = aws_apigatewayv2_api.visitor_counter.id
  integration_type        = "AWS_PROXY"
  integration_uri         = aws_lambda_function.visitor_counter.arn
  payload_format_version  = "2.0"
}

resource "aws_apigatewayv2_route" "visitor_counter" {
  provider  = aws.us_east_1
  api_id    = aws_apigatewayv2_api.visitor_counter.id
  route_key = "GET /count"
  target    = "integrations/${aws_apigatewayv2_integration.visitor_counter.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  provider    = aws.us_east_1
  api_id      = aws_apigatewayv2_api.visitor_counter.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 14
    throttling_rate_limit  = 7
  }
}