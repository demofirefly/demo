provider "aws" {
  region = local.region
}



locals {
  name   = "demo-mysql"
  region = "eu-north-1"
  tags = {
    Owner       = "user"
    Environment = "demo"
  }
}


terraform {
 backend "s3" {
    bucket = "tfstates.tf"
    key    = "tfstates/rds_ghost.tfstate"
    region = "eu-west-1"
  }
}


################################################################################
# Supporting Resources
################################################################################

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"
 for_each = toset(["1", "2", "3","4","5"])
  name = "${local.name}${each.key}"
  cidr = "10.99.0.0/18"

  azs              = ["${local.region}a", "${local.region}b", "${local.region}c"]
  public_subnets   = ["10.99.0.0/24", "10.99.1.0/24", "10.99.2.0/24"]
  private_subnets  = ["10.99.3.0/24", "10.99.4.0/24", "10.99.5.0/24"]
  database_subnets = ["10.99.7.0/24", "10.99.8.0/24", "10.99.9.0/24"]

  create_database_subnet_group = true

  tags = local.tags
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"
  for_each = toset(["1", "2", "3","4","5"])
  name        = local.name
  description = "Complete MySQL example security group"
  vpc_id      = module.vpc[each.key].vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "MySQL access from within VPC"
      cidr_blocks = module.vpc[each.key].vpc_cidr_block
    },
  ]

  tags = local.tags
}

################################################################################
# RDS Module
################################################################################

module "db" {
  source = "terraform-aws-modules/rds/aws"
   for_each = toset(["1", "2", "3","4","5"])
  identifier = "${local.name}${each.key}"

  # All available versions: http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html#MySQL.Concepts.VersionMgmt
  engine               = "mysql"
  engine_version       = "8.0.27"
  family               = "mysql8.0" # DB parameter group
  major_engine_version = "8.0"      # DB option group
  instance_class       = "db.t4g.large"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = "completeMysql"
  username = "complete_mysql"
  port     = 3306

  multi_az               = true
  subnet_ids             = module.vpc[each.key].database_subnets
  vpc_security_group_ids = [module.security_group[each.key].security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["general"]
  create_cloudwatch_log_group     = true

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false

  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  create_monitoring_role                = false
  monitoring_interval                   = 0

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  ]

  tags = local.tags
  db_instance_tags = {
    "Sensitive" = "high"
  }
  db_option_group_tags = {
    "Sensitive" = "low"
  }
  db_parameter_group_tags = {
    "Sensitive" = "low"
  }
  db_subnet_group_tags = {
    "Sensitive" = "high"
  }
}


module "db_disabled" {
 source = "terraform-aws-modules/rds/aws"
   for_each = toset(["1", "2", "3","4","5"])
  identifier = "${local.name}-disabled"

  create_db_instance        = false
  create_db_parameter_group = false
  create_db_option_group    = false
}