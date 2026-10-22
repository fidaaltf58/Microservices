# One database per service, matching the docker-compose layout:
#   product-service -> MySQL,  order-service -> PostgreSQL
locals {
  databases = {
    product = {
      engine            = "mysql"
      engine_version    = "8.4"
      family            = "mysql8.4"
      port              = 3306
      db_name           = "productdb"
      username          = "product_admin"
      log_exports       = ["error", "general", "slowquery"]
      jdbc_scheme       = "mysql"
      jdbc_tls_param    = "sslMode=REQUIRED"
      require_tls_param = { name = "require_secure_transport", value = "1" }
    }
    order = {
      engine            = "postgres"
      engine_version    = "16"
      family            = "postgres16"
      port              = 5432
      db_name           = "orderdb"
      username          = "order_admin"
      log_exports       = ["postgresql", "upgrade"]
      jdbc_scheme       = "postgresql"
      jdbc_tls_param    = "sslmode=require"
      require_tls_param = { name = "rds.force_ssl", value = "1" }
    }
  }
}

resource "aws_security_group" "db" {
  for_each = local.databases
  #checkov:skip=CKV2_AWS_5:Attached to aws_db_instance.db via vpc_security_group_ids (for_each is not traced by the check)

  name        = "${local.name}-${each.key}-db"
  description = "${each.key} database: inbound only from EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "${each.value.engine} from EKS nodes (pods use the node security group)"
    from_port       = each.value.port
    to_port         = each.value.port
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  # No egress rules: the database never initiates connections
}

# Reject any client connection that is not TLS-encrypted
resource "aws_db_parameter_group" "db" {
  for_each = local.databases

  name   = "${local.name}-${each.key}"
  family = each.value.family

  parameter {
    name         = each.value.require_tls_param.name
    value        = each.value.require_tls_param.value
    apply_method = "pending-reboot"
  }

  dynamic "parameter" {
    for_each = each.value.engine == "postgres" ? {
      log_statement              = "ddl"
      log_min_duration_statement = "1000"
    } : {}
    content {
      name  = parameter.key
      value = parameter.value
    }
  }
}

resource "random_password" "db" {
  for_each = local.databases

  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?" # excludes / @ " and space, which RDS rejects
}

resource "aws_db_instance" "db" {
  for_each = local.databases
  #checkov:skip=CKV_AWS_157:Multi-AZ is controlled by var.db_multi_az (off for the dev environment to save cost)
  #checkov:skip=CKV_AWS_293:Deletion protection is controlled by var.db_deletion_protection (off in dev so the stack can be torn down)
  #checkov:skip=CKV_AWS_353:Performance Insights is not available on the db.t4g.micro dev instance class
  #checkov:skip=CKV_AWS_354:Same as CKV_AWS_353
  #checkov:skip=CKV2_AWS_69:TLS is enforced by aws_db_parameter_group.db (require_secure_transport / rds.force_ssl); the check cannot follow for_each

  identifier     = "${local.name}-${each.key}"
  engine         = each.value.engine
  engine_version = each.value.engine_version
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.platform.arn

  db_name  = each.value.db_name
  username = each.value.username
  password = random_password.db[each.key].result
  port     = each.value.port

  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db[each.key].id]
  parameter_group_name   = aws_db_parameter_group.db[each.key].name
  publicly_accessible    = false
  multi_az               = var.db_multi_az

  iam_database_authentication_enabled = true
  auto_minor_version_upgrade          = true
  enabled_cloudwatch_logs_exports     = each.value.log_exports
  monitoring_interval                 = 60
  monitoring_role_arn                 = aws_iam_role.rds_monitoring.arn

  backup_retention_period   = 7
  copy_tags_to_snapshot     = true
  deletion_protection       = var.db_deletion_protection
  skip_final_snapshot       = !var.db_deletion_protection
  final_snapshot_identifier = var.db_deletion_protection ? "${local.name}-${each.key}-final" : null
}

# Connection details for the application, read in-cluster by External Secrets Operator.
# The secret name is deterministic so the Kubernetes manifests can reference it without Terraform outputs.
resource "aws_secretsmanager_secret" "db" {
  for_each = local.databases
  #checkov:skip=CKV2_AWS_57:Rotation needs a rotation Lambda plus a pod restart on change; tracked as a roadmap item in the README

  name                    = "${local.name}/${each.key}-db"
  description             = "JDBC connection settings for ${each.key}-service"
  kms_key_id              = aws_kms_key.platform.arn
  recovery_window_in_days = var.secret_recovery_window_days
}

resource "aws_secretsmanager_secret_version" "db" {
  for_each = local.databases

  secret_id = aws_secretsmanager_secret.db[each.key].id
  secret_string = jsonencode({
    username = each.value.username
    password = random_password.db[each.key].result
    url      = "jdbc:${each.value.jdbc_scheme}://${aws_db_instance.db[each.key].address}:${each.value.port}/${each.value.db_name}?${each.value.jdbc_tls_param}"
  })
}

# Enhanced Monitoring (OS-level metrics every 60s)
data "aws_iam_policy_document" "rds_monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "${local.name}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume.json
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
