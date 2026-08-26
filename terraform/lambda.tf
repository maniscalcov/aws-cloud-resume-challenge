resource "aws_lambda_function" "visitor_counter" {
  function_name = "cloud-resume-visitor-counter"
  role          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/service-role/cloud-resume-visitor-counter-role-yj4bpqxx"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.13"
# Placeholder zip — Terraform requires a code source, but this resource was imported
# from existing code; ignore_changes below stops Terraform from overwriting it.
  filename = "lambda_placeholder.zip"

  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}