resource "aws_s3_bucket" "resume_site" {
  bucket = "vinnys-cloud-resume-584477830979-us-east-2-an"

  tags = {
    project = "Cloud Resume callenge"
  }
}

resource "aws_s3_bucket_public_access_block" "resume_site" {
  bucket = aws_s3_bucket.resume_site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}