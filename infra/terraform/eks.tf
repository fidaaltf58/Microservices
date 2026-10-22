module "eks" {
  #checkov:skip=CKV_TF_1:Registry module pinned to an exact version; provider checksums are locked in .terraform.lock.hcl
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.2"

  cluster_name    = local.name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # API endpoint: always reachable from inside the VPC; publicly only from the admin CIDRs (if any)
  cluster_endpoint_private_access      = true
  cluster_endpoint_public_access       = length(var.admin_cidrs) > 0
  cluster_endpoint_public_access_cidrs = var.admin_cidrs

  # Access is granted through EKS access entries (IAM), not the legacy aws-auth ConfigMap
  authentication_mode                      = "API"
  enable_cluster_creator_admin_permissions = true

  # Control-plane audit trail in CloudWatch
  cluster_enabled_log_types              = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cloudwatch_log_group_retention_in_days = 30

  # Kubernetes Secrets are envelope-encrypted with a module-managed, rotated KMS key (create_kms_key defaults to true)

  # IAM Roles for Service Accounts (IRSA): pods get scoped AWS credentials, never node credentials
  enable_irsa = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
      # Turns on the VPC CNI network-policy agent so Kubernetes NetworkPolicies are actually enforced
      configuration_values = jsonencode({
        enableNetworkPolicy = "true"
      })
    }
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type

      min_size     = var.node_min_size
      desired_size = var.node_desired_size
      max_size     = var.node_max_size

      # IMDSv2 only, and a hop limit of 1 so pods cannot reach the node's instance profile credentials
      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 1
      }

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 30
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }
    }
  }

  # The CI/CD role may only manage resources inside the application namespace
  access_entries = {
    github_actions = {
      principal_arn = aws_iam_role.github_actions.arn

      policy_associations = {
        app_namespace = {
          policy_arn = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = [local.app_namespace]
          }
        }
      }
    }
  }
}
