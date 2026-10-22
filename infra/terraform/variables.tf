variable "project" {
  description = "Project name, used as a prefix for every resource."
  type        = string
  default     = "ecommerce"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-3"
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "kubernetes_version" {
  description = "EKS control plane version."
  type        = string
  default     = "1.33"
}

variable "admin_cidrs" {
  description = "CIDRs allowed to reach the public EKS API endpoint. Empty list = private endpoint only."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "admin_cidrs must be valid CIDRs and must not be 0.0.0.0/0."
  }
}

variable "node_instance_types" {
  description = "Instance types for the managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT. SPOT cuts node cost by ~60-70% for a dev cluster."
  type        = string
  default     = "SPOT"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "db_instance_class" {
  description = "RDS instance class for both databases."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_multi_az" {
  description = "Run each database with a standby in a second AZ."
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Protect databases from deletion and take a final snapshot on destroy. Enable outside dev."
  type        = bool
  default     = false
}

variable "secret_recovery_window_days" {
  description = "Days a deleted secret stays recoverable. 0 lets a dev stack be destroyed and recreated immediately."
  type        = number
  default     = 0
}

variable "ecr_force_delete" {
  description = "Allow terraform destroy to delete ECR repositories that still contain images."
  type        = bool
  default     = true
}

variable "github_repository" {
  description = "GitHub repository (owner/name) allowed to assume the CI/CD deploy role through OIDC."
  type        = string
  default     = "fidaaltf58/Microservices"
}

variable "github_branch" {
  description = "Only workflows running on this branch can assume the deploy role."
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub Actions OIDC provider. Set to false if the account already has one."
  type        = bool
  default     = true
}
