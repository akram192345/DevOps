# Infrastructure as code for the fintech ledger service.
# One definition, four environments: dev/test/staging/production differ only by
# the .tfvars file supplied at apply time. That is what removes environment
# drift as a cause of "cannot reproduce the production bug".

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60" # pinned: an unpinned provider is undeclared drift
    }
  }

  # Remote state with locking, so two engineers cannot apply at once and no
  # one holds infrastructure state on a laptop.
  backend "s3" {
    bucket         = "fintech-tfstate"
    key            = "ledger/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "fintech-tfstate-locks"
    encrypt        = true
  }
}

variable "environment" {
  description = "dev | test | staging | production"
  type        = string
  validation {
    condition     = contains(["dev", "test", "staging", "production"], var.environment)
    error_message = "environment must be one of dev, test, staging, production."
  }
}

variable "image_digest" {
  description = "Immutable image reference, e.g. app@sha256:abc123. Never a tag."
  type        = string
}

variable "desired_replicas" {
  type    = number
  default = 2
}

locals {
  # Cost allocation tags are mandatory - they are what makes FinOps showback
  # possible, and a policy-as-code rule rejects any resource missing them.
  common_tags = {
    Application = "ledger-api"
    Environment = var.environment
    CostCentre  = "retail-banking"
    Owner       = "payments-platform"
    ManagedBy   = "terraform"
  }
}

resource "aws_ecr_repository" "ledger" {
  name                 = "ledger-api"
  image_tag_mutability = "IMMUTABLE" # a published tag can never be overwritten

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = local.common_tags
}

resource "aws_db_instance" "ledger" {
  identifier              = "ledger-${var.environment}"
  engine                  = "postgres"
  instance_class          = var.environment == "production" ? "db.m6g.large" : "db.t4g.micro"
  allocated_storage       = var.environment == "production" ? 100 : 20
  multi_az                = var.environment == "production"
  storage_encrypted       = true
  backup_retention_period = var.environment == "production" ? 35 : 1
  deletion_protection     = var.environment == "production"

  # RPO: point-in-time recovery gives a recovery point within ~5 minutes.
  # RTO: Multi-AZ failover completes in roughly 60-120 seconds.
  tags = local.common_tags
}

resource "kubernetes_deployment" "green" {
  metadata {
    name   = "ledger-api-green"
    labels = { app = "ledger-api", slot = "green" }
  }

  spec {
    replicas = var.desired_replicas

    template {
      spec {
        container {
          name  = "api"
          image = var.image_digest # digest, not tag - the artefact is immutable

          liveness_probe {
            http_get { path = "/healthz" port = 8000 }
            initial_delay_seconds = 10
          }

          readiness_probe {
            http_get { path = "/healthz" port = 8000 }
          }

          security_context {
            run_as_non_root            = true
            read_only_root_filesystem  = true
            allow_privilege_escalation = false
          }
        }
      }
    }
  }
}

output "image_digest_deployed" {
  value       = var.image_digest
  description = "Recorded in the release record as audit evidence."
}
