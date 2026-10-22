# Three subnet tiers across two AZs:
#   public   /24  - load balancers and the NAT gateway only
#   private  /20  - EKS worker nodes and pods (VPC CNI gives pods VPC IPs, hence the larger range)
#   database /24  - RDS, no route to the internet at all
module "vpc" {
  #checkov:skip=CKV_TF_1:Registry module pinned to an exact version; provider checksums are locked in .terraform.lock.hcl
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.21.0"

  name = local.name
  cidr = var.vpc_cidr
  azs  = local.azs

  public_subnets   = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 1)]
  database_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 100)]

  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  # One NAT gateway keeps a dev stack cheap; use one per AZ (single_nat_gateway = false) in production.
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  # The default security group allows all traffic between its members; strip every rule from it.
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  # VPC flow logs for network forensics
  enable_flow_log                                 = true
  create_flow_log_cloudwatch_log_group            = true
  create_flow_log_cloudwatch_iam_role             = true
  flow_log_max_aggregation_interval               = 60
  flow_log_cloudwatch_log_group_retention_in_days = 30

  # Let Kubernetes find the right subnets for public and internal load balancers
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}
