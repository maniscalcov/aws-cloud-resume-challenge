# ── Cost backstop ────────────────────────────────────────────────
# Monthly budget across the whole account. Emails at 80% and 100% of
# actual spend, plus when AWS forecasts the month will go over.
# Email notifications from Budgets don't need a confirmation click.

variable "budget_alert_email" {
  description = "Email address for AWS Budget alerts (set in terraform.tfvars, which is gitignored)"
  type        = string
}

resource "aws_budgets_budget" "monthly" {
  name         = "cloud-resume-monthly"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}
