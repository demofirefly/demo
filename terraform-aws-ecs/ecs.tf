provider "aws" {
  region = local.region
}

terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
    }
  }
}


terraform {
 backend "s3" {
    bucket = "tfstates.tf"
    key    = "tfstates/ecs.tfstate"
    region = "eu-west-1"
  }
}

locals {
  region = "eu-west-3"
  name   = "ecs-ex-${replace(basename(path.cwd), "_", "-")}"

  user_data = <<-EOT
    #!/bin/bash
    cat <<'EOF' >> /etc/ecs/ecs.config
    ECS_CLUSTER=${local.name}
    ECS_LOGLEVEL=debug
    EOF
  EOT

  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/terraform-aws-modules/terraform-aws-ecs"
  }
}

################################################################################
# ECS Module
################################################################################

module "ecs" {
  source = "terraform-aws-modules/ecs/aws"
  for_each = toset(["1", "2", "3","4","5","6","7","8","9","10"])
  cluster_name = "${local.name}-${each.key}"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        # You can set a simple string and ECS will create the CloudWatch log group for you
        # or you can create the resource yourself as shown here to better manage retetion, tagging, etc.
        # Embedding it into the module is not trivial and therefore it is externalized
        cloud_watch_log_group_name = aws_cloudwatch_log_group.this.name
      }
    }
  }

  default_capacity_provider_use_fargate = false

  # Capacity provider - Fargate
  fargate_capacity_providers = {
    FARGATE      = {}
    FARGATE_SPOT = {}
  }

  # Capacity provider - autoscaling groups
  autoscaling_capacity_providers = {
    one = {
      auto_scaling_group_arn         = module.autoscaling["one"].autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 5
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 60
      }

      default_capacity_provider_strategy = {
        weight = 60
        base   = 20
      }
    }
    two = {
      auto_scaling_group_arn         = module.autoscaling["two"].autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 15
        minimum_scaling_step_size = 5
        status                    = "ENABLED"
        target_capacity           = 90
      }

      default_capacity_provider_strategy = {
        weight = 40
      }
    }
        three = {
      auto_scaling_group_arn         = module.autoscaling["three"].autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 3
        minimum_scaling_step_size = 1
        status                    = "ENABLED"
        target_capacity           = 50
      }

      default_capacity_provider_strategy = {
        weight = 20
      }
    }
        four = {
      auto_scaling_group_arn         = module.autoscaling["four"].autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 10
        minimum_scaling_step_size = 2
        status                    = "ENABLED"
        target_capacity           = 20
      }

      default_capacity_provider_strategy = {
        weight = 40
      }
    }
        five = {
      auto_scaling_group_arn         = module.autoscaling["five"].autoscaling_group_arn
      managed_termination_protection = "ENABLED"

      managed_scaling = {
        maximum_scaling_step_size = 10
        minimum_scaling_step_size = 2
        status                    = "ENABLED"
        target_capacity           = 50
      }

      default_capacity_provider_strategy = {
        weight = 30
      }
    }
       
  }

  tags = local.tags
}

module "hello_world" {
  source = "./service-hello-world"
    for_each = toset(["1", "2", "3","4","5"])
  cluster_id = module.ecs[each.key].cluster_id
}

module "ecs_disabled" {
  source = "terraform-aws-modules/ecs/aws"

  create = false
}

################################################################################
# Supporting Resources
################################################################################

# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-optimized_AMI.html#ecs-optimized-ami-linux
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended"
}

module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 6.5"
 
  for_each = {
    one = {
      instance_type = "t3.micro"
    }
    two = {
      instance_type = "t3.small"
    }
        three = {
      instance_type = "t3.micro"
    }
        four = {
      instance_type = "t3.micro"
    }
        five = {
      instance_type = "t3.micro"
    }
        six = {
      instance_type = "t3.micro"
    }
        seven = {
      instance_type = "t3.micro"
    }
        eight = {
      instance_type = "t3.micro"
    }
        nine = {
      instance_type = "t3.micro"
    }
        ten = {
      instance_type = "t3.micro"
    }
  }

  name = "${local.name}-${each.key}"

  image_id      = jsondecode(data.aws_ssm_parameter.ecs_optimized_ami.value)["image_id"]
  instance_type = each.value.instance_type

  security_groups                 = [module.autoscaling_sg[each.key].security_group_id]
  user_data                       = base64encode(local.user_data)
  ignore_desired_capacity_changes = true

  create_iam_instance_profile = true
  iam_role_name               = local.name
  iam_role_description        = "ECS role for ${local.name}"
  iam_role_policies = {
    AmazonEC2ContainerServiceforEC2Role = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
    AmazonSSMManagedInstanceCore        = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  vpc_zone_identifier = module.vpc.private_subnets
  health_check_type   = "EC2"
  min_size            = 0
  max_size            = 2
  desired_capacity    = 1

  # https://github.com/hashicorp/terraform-provider-aws/issues/12582
  autoscaling_group_tags = {
    AmazonECSManaged = true
  }

  # Required for  managed_termination_protection = "ENABLED"
  protect_from_scale_in = true

  tags = local.tags
}

module "autoscaling_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"
  for_each = toset(["one", "two", "three","four","five","six","seven","eight","nine","ten"])
  name        = "${local.name}-${each.value}"
  description = "Autoscaling group security group"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp"]

  egress_rules = ["all-all"]

  tags = local.tags
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = "10.99.0.0/18"

  azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
  public_subnets  = ["10.99.0.0/24", "10.99.1.0/24", "10.99.2.0/24"]
  private_subnets = ["10.99.3.0/24", "10.99.4.0/24", "10.99.5.0/24"]

  enable_nat_gateway      = true
  single_nat_gateway      = true
  enable_dns_hostnames    = true
  map_public_ip_on_launch = false

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/ecs/${local.name}"
  retention_in_days = 7

  tags = local.tags
}