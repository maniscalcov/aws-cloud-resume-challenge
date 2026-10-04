# AWS Cloud Resume Challenge

This is a resume site built on aws, I built this project to differ from the normal cloud resume challenge by adding in a working AI chatbot and also adding in a working contact me. This project is managed and provisioned through terraform.

**Live site:** https://vinnymaniscalco.dev

---

## What's on it

- **Static resume site** — HTML/CSS/JS, served from S3 through CloudFront with a custom Origin Access Control and AWS WAF in front of it
- **Visitor counter** — DynamoDB atomic counter behind a Lambda function and API Gateway, updating on every page load
- **AI chatbot** — a terminal-styled widget that answers questions about my background, backed by Amazon Bedrock (Claude Haiku) with per-session conversation memory and daily cost caps
- **Contact form** — submits through API Gateway and Lambda to Amazon SES, with reply-to routing so replies go straight back to the sender
- **Fully Terraform-managed** — every resource above is defined as code, imported into state, and deployable with `terraform apply`
- **CI/CD** — GitHub Actions syncs the site to S3 and invalidates CloudFront on every push to `main`, authenticated via OIDC with no long-lived AWS keys stored in GitHub

---

## Architecture

```
                        ┌─────────────┐
  visitor ──────────────▶  CloudFront │◀── WAF
                        └──────┬──────┘
                               │
                        ┌──────▼──────┐
                        │   S3 (OAC)  │  static site files
                        └─────────────┘

  Visitor Counter (us-east-1)
  Browser ─▶ API Gateway ─▶ Lambda ─▶ DynamoDB (atomic counter)

  AI Chatbot (us-east-2)
  Browser ─▶ API Gateway ─▶ Lambda ─▶ Bedrock (Claude Haiku)
                              │
                              ▼
                        DynamoDB (sessions, 24h TTL + daily rate limit)

  Contact Form (us-east-2, shares chatbot's API Gateway)
  Browser ─▶ API Gateway ─▶ Lambda ─▶ SES (reply-to: submitter)
```

Chatbot and contact form share one API Gateway in `us-east-2`; the visitor counter's infrastructure predates that and lives in `us-east-1`. Multi-region providers are declared explicitly in Terraform via aliases.

---

## Tech stack

| Layer | Tools |
|---|---|
| Frontend | HTML5, vanilla JS, CSS (HTML5UP template, customized) |
| Compute | AWS Lambda (Python 3.13) |
| AI | Amazon Bedrock — Claude Haiku via inference profile |
| Data | DynamoDB |
| API | API Gateway (HTTP API) |
| Delivery | S3, CloudFront, AWS WAF |
| Email | Amazon SES |
| IaC | Terraform |
| CI/CD | GitHub Actions (OIDC) |

---

## Cost controls on the chatbot

Since the chatbot calls a paid LLM API, I added in some protection on 3 different layers so traffic spikes will not cost me to have a spike in cost:

1. **API Gateway throttling** — 2 requests/sec, burst of 5
2. **Daily quota** — a hard cap on total chatbot messages per day, enforced via an atomic DynamoDB counter
3. **Per-call limits** — capped input length, capped output tokens, and a trimmed conversation history window

---

## What I learned

- Bedrock requires the inference profile ARN, not the foundation model ARN, and the first invocation needs marketplace-subscription permissions on the Lambda's execution role. During this step I ran into the error where I did not have the correct limit and was required to incress them.
- API Gateway's CORS configuration alone doesn't add headers to Lambda proxy integration responses, the Lambda itself has to return them.
- S3 object keys are case-sensitive; `.JPG` and `.jpg` are different objects, and a mismatch returns a 403, not a 404. During my editing of the site I placed a file with the wrong caps ran into this error.
- Terraform's `state rm` and provider aliasing become essential fast once a project spans more than one AWS region
- Least-privilege IAM policies for a `terraform-cli` user tend to grow with every new resource added. I started with limited permissions and needed to adjust my permisions with most of my new resouces.

---

## Certifications

- [AWS Certified Cloud Practitioner](https://www.credly.com/badges/605e28f5-cfc5-4ac7-9507-5c8ebdca86ed/public_url)
- [AWS Certified Solutions Architect – Associate (SAA-C03)](https://www.credly.com/badges/4e743fb7-5a70-43d7-ba1f-8a10223316bf/public_url)

---

## Roadmap

- [x] Static site on S3 + CloudFront
- [x] Visitor counter (DynamoDB + Lambda + API Gateway)
- [x] AI chatbot (Bedrock + Lambda + DynamoDB sessions)
- [x] Contact form (SES + Lambda)
- [x] Full Terraform coverage
- [x] CI/CD via GitHub Actions
- [x] Custom domain via Route 53 (ACM cert + CloudFront alias, managed in Terraform)
- [ ] AWS Budget alert as a cost backstop

---

## Running this yourself

```bash
git clone https://github.com/maniscalcov/aws-cloud-resume-challenge.git
cd aws-cloud-resume-challenge/terraform
terraform init
terraform plan
terraform apply
```

You'll need your own S3 bucket, verified SES identity, and Bedrock model access configured first — see the Terraform files for the exact resources and required variables.
