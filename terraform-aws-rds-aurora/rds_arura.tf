    provider "aws" {
  region = local.region
}



locals {
  name   = "ex-${replace(basename(path.cwd), "_", "-")}"
  region = "eu-west-3"

  tags = {
    Example    = local.name
    GithubRepo = "terraform-aws-rds-aurora"
    GithubOrg  = "terraform-aws-modules"
  }
}

################################################################################
# RDS Aurora Module
################################################################################

module "aurora" {
  source = "terraform-aws-modules/rds-aurora/aws"
   for_each = toset(["1", "2", "3","4","5","6","7","8","9","10","11","12","13","14","15","16","17"])
  name           = "${local.name}-${each.key}"
  engine         = "aurora-postgresql"
  engine_version = "11.12"
  instance_class = "db.r6g.large"
  instances      = { 3 = {} }

  vpc_id                 = module.vpc.vpc_id
  db_subnet_group_name   = module.vpc.database_subnet_group_name
  create_db_subnet_group = false
  create_security_group  = true
  allowed_cidr_blocks    = module.vpc.private_subnets_cidr_blocks

  autoscaling_enabled      = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 5

  monitoring_interval           = 60
  iam_role_name                 = "${local.name}-monitor"
  iam_role_use_name_prefix      = true
  iam_role_description          = "${local.name} RDS enhanced monitoring IAM role"
  iam_role_path                 = "/autoscaling/"
  iam_role_max_session_duration = 7200

  apply_immediately   = true
  skip_final_snapshot = true

  db_parameter_group_name         = aws_db_parameter_group.example[each.key].id
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.example[each.key].id
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = local.tags
}

resource "aws_db_parameter_group" "example" {
   for_each = toset(["1", "2", "3","4","5","6","7","8","9","10","11","12","13","14","15","16","17"])
  name_prefix = "${local.name}-aurora-db-postgres11-parameter-group-${each.key}"
  family      = "aurora-postgresql11"
  description = "${local.name}-aurora-db-postgres11-parameter-group"
  tags        = local.tags
}

resource "aws_rds_cluster_parameter_group" "example" {
  for_each = toset(["1", "2", "3","4","5","6","7","8","9","10","11","12","13","14","15","16","17"])
  name_prefix = "${local.name}-aurora-postgres11-cluster-parameter-group-${each.key}"
  family      = "aurora-postgresql11"
  description = "${local.name}-aurora-postgres11-cluster-parameter-group"
  tags        = local.tags
}

module "disabled_aurora" {
  source = "terraform-aws-modules/rds-aurora/aws"

  create_cluster = false
}

################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = "10.99.0.0/18"

  enable_dns_support   = true
  enable_dns_hostnames = true

  azs              = ["${local.region}a", "${local.region}b", "${local.region}c"]
  public_subnets   = ["10.99.0.0/24", "10.99.1.0/24", "10.99.2.0/24"]
  private_subnets  = ["10.99.3.0/24", "10.99.4.0/24", "10.99.5.0/24"]
  database_subnets = ["10.99.7.0/24", "10.99.8.0/24", "10.99.9.0/24"]

  enable_nat_gateway = false # Disabled NAT to be able to run this example quicker

  tags = local.tags
}