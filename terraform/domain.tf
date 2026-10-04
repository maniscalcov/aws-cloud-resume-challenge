# ── Custom domain ────────────────────────────────────────────────
# Route 53 created the hosted zone automatically when the domain was
# registered, so we look it up instead of creating a second one
# (a duplicate zone would have different nameservers and DNS would fail).

locals {
  site_domains = [var.domain_name, "www.${var.domain_name}"]

  # Origins allowed to call the API Gateways (visitor counter + chatbot/contact).
  # The CloudFront URL stays in the list until the custom domain is confirmed working.
  cors_origins = concat(
    ["https://d3v6sllvp0c9mk.cloudfront.net"],
    [for d in local.site_domains : "https://${d}"]
  )
}

data "aws_route53_zone" "site" {
  name         = var.domain_name
  private_zone = false
}

# CloudFront only accepts ACM certificates from us-east-1
resource "aws_acm_certificate" "site" {
  provider                  = aws.us_east_1
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"

  tags = { Project = "cloud-resume-challenge" }

  lifecycle {
    create_before_destroy = true
  }
}

# DNS records ACM checks to prove we own the domain
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = data.aws_route53_zone.site.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

# Waits until ACM marks the cert as Issued (usually a few minutes)
resource "aws_acm_certificate_validation" "site" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# Alias records pointing the domain (and www) at CloudFront — IPv4 and IPv6
resource "aws_route53_record" "site_a" {
  for_each = toset(local.site_domains)

  zone_id = data.aws_route53_zone.site.zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.resume_site.domain_name
    zone_id                = aws_cloudfront_distribution.resume_site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "site_aaaa" {
  for_each = toset(local.site_domains)

  zone_id = data.aws_route53_zone.site.zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.resume_site.domain_name
    zone_id                = aws_cloudfront_distribution.resume_site.hosted_zone_id
    evaluate_target_health = false
  }
}
