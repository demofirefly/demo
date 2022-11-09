terraform {
    required_providers {
    aws = {
          source  = "hashicorp/aws"
          version = ">= 2.7.0"
        }
      }

    }


######################
# IAM assumable roles
######################
module "iam_assumable_roles_iam" {
  source = "terraform-aws-modules/iam/aws//modules/iam-read-only-policy"
  for_each = toset(["1", "2", "3","4","5","6","7","8","9","10","12","13","14","15","16"])
  name        = "role-${each.key}"
  path        = "/"
  description = "My example read-only policy"

  allowed_services = ["rds"]
}

module "iam_policy_iam" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  for_each = toset(["1", "2", "3","4","5","6","7","8","9","10","12","13","14","15","16"])
  name        = "a_role-${each.key}"
  path        = "/"
  description = "My example policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ec2:Describe*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

module "iam_user_iam" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-user"
  for_each = toset(["1", "2", "3","4","5","6","7","8","9","10","12","13","14","15","16"])
  name        = "b_role-${each.key}"
  force_destroy = true

  pgp_key = "keybase:test"

  password_reset_required = false
  tags ={
    env = "demo"
  }
}