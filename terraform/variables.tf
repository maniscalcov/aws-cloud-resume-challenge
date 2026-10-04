variable "aws_region" {
  description = "AWS region for resources"
  default     = "us-east-2"
}

variable "domain_name" {
  description = "Custom domain registered in Route 53 (apex, no www), e.g. example.com"
  type        = string
  default     = "vinnymaniscalco.dev"
}
