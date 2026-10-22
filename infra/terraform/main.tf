data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_availability_zones" "available" {
  #checkov:skip=CKV_AWS_394:Only the first two zones are used (slice below), so new AZs never change the selection
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  name       = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  azs        = slice(data.aws_availability_zones.available.names, 0, 2)

  # Kubernetes namespace the application runs in (must match k8s/namespace)
  app_namespace = "ecommerce"

  services = ["eureka-server", "config-server", "api-gateway", "product-service", "order-service"]

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = var.github_repository
  }
}

# ---------------------------------------------------------------------------
# Customer-managed KMS key: encrypts ECR images, RDS storage and DB secrets.
# (EKS creates and rotates its own key for Kubernetes Secrets envelope encryption.)
# ---------------------------------------------------------------------------
data "aws_iam_policy_document" "kms" {
  #checkov:skip=CKV_AWS_109:Root-account statement is the standard key-admin delegation to IAM; it is not a resource-level wildcard grant to other principals
  #checkov:skip=CKV_AWS_111:Same as above, required so IAM policies can grant use of the key
  #checkov:skip=CKV_AWS_356:A key policy's Resource is always the key itself ("*" means this key)
  statement {
    sid       = "EnableIAMPolicies"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }
}

resource "aws_kms_key" "platform" {
  description             = "${local.name} platform key (ECR, RDS, Secrets Manager)"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.kms.json
}

resource "aws_kms_alias" "platform" {
  name          = "alias/${local.name}-platform"
  target_key_id = aws_kms_key.platform.key_id
}
