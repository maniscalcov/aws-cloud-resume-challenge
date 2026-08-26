resource "aws_cloudfront_origin_access_control" "resume_site" {
  name                              = "resume-site-oac"
  description                       = "S3 resume challenge"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "resume_site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  web_acl_id          = "arn:aws:wafv2:us-east-1:${data.aws_caller_identity.current.account_id}:global/webacl/CreatedByCloudFront-ccb9ec2c/4e4dcdb7-91e4-4f4e-9a2f-9e99948121ee"

  tags = {
    Name = "Cloud-resume"
  }

  origin {
    domain_name              = aws_s3_bucket.resume_site.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.resume_site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.resume_site.id
  }

  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.resume_site.bucket_regional_domain_name
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods          = ["GET", "HEAD"]
    compress                = true
    cache_policy_id         = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}