
provider "aws" {
  region = "eu-west-3"

  # Make it faster by skipping something
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true

}


terraform {
 backend "s3" {
    bucket = "tfstates.tf"
    key    = "tfstates/lambda.tfstate"
    region = "eu-west-1"
  }
}




data "aws_caller_identity" "current" {}

####################################################
# Lambda Function (building locally, storing on S3,
# set allowed triggers, set policies)
####################################################

module "lambda_function_lambda" {
  source = "terraform-aws-modules/lambda/aws"
 for_each = toset(["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "tweleve", "thirteen", "fourteen","fiveteen"])
  function_name          = "${random_pet.this_lambda.id}-lambda-demo-1"
  description            = "demo function"
  handler                = "index.lambda_handler"
  runtime                = "python3.8"
  ephemeral_storage_size = 10240
  architectures          = ["x86_64"]
  publish                = true

  source_path = "C:/Work_Firefly/Demo/terraform-aws-lambda/hello.py"

  store_on_s3 = true
  s3_bucket   = module.s3_bucket_lambda.s3_bucket_id
  s3_prefix   = "lambda-builds/"

  artifacts_dir = "${path.root}/.terraform/lambda-builds/"

  layers = [
    module.lambda_layer_local[each.key].lambda_layer_arn,
    module.lambda_layer_s3[each.key].lambda_layer_arn,
  ]

  environment_variables = {
    Hello      = "World"
    Serverless = "Terraform"
  }

  role_path   = "/tf-managed/"
  policy_path = "/tf-managed/"

  attach_dead_letter_policy = true
  dead_letter_target_arn    = aws_sqs_queue.dlq.arn

  allowed_triggers = {
    APIGatewayAny = {
      service    = "apigateway"
      source_arn = "arn:aws:execute-api:eu-west-1:${data.aws_caller_identity.current.account_id}:aqnku8akd0/*/*/*"
    },
    APIGatewayDevPost = {
      service    = "apigateway"
      source_arn = "arn:aws:execute-api:eu-west-1:${data.aws_caller_identity.current.account_id}:aqnku8akd0/dev/POST/*"
    },
    OneRule = {
      principal  = "events.amazonaws.com"
      source_arn = "arn:aws:events:eu-west-1:${data.aws_caller_identity.current.account_id}:rule/RunDaily"
    }
  }

  ######################
  # Lambda Function URL
  ######################
  create_lambda_function_url = true
  authorization_type         = "AWS_IAM"
  cors = {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }

  ######################
  # Additional policies
  ######################

  assume_role_policy_statements = {
    account_root = {
      effect  = "Allow",
      actions = ["sts:AssumeRole"],
      principals = {
        account_principal = {
          type        = "AWS",
          identifiers = ["arn:aws:iam::${each.key}${data.aws_caller_identity.current.account_id}:root"]
        }
      }
      condition = {
        stringequals_condition = {
          test     = "StringEquals"
          variable = "sts:ExternalId"
          values   = ["12345"]
        }
      }
    }
  }

  attach_policy_json = true
  policy_json        = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "xray:GetSamplingStatisticSummaries"
            ],
            "Resource": ["*"]
        }
    ]
}
EOF

  attach_policy_jsons = true
  policy_jsons = [<<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "xray:*"
            ],
            "Resource": ["*"]
        }
    ]
}
EOF
  ]
  number_of_policy_jsons = 1

  attach_policy = true
  policy        = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"

  attach_policies    = true
  policies           = ["arn:aws:iam::aws:policy/AWSXrayReadOnlyAccess"]
  number_of_policies = 1

  attach_policy_statements = true
  policy_statements = {
    dynamodb = {
      effect    = "Allow",
      actions   = ["dynamodb:BatchWriteItem"],
      resources = ["arn:aws:dynamodb:eu-west-1:052212379155:table/Test"]
    },
    s3_read = {
      effect    = "Deny",
      actions   = ["s3:HeadObject", "s3:GetObject"],
      resources = ["arn:aws:s3:::my-bucket/*"]
    }
  }

  ###########################
  # END: Additional policies
  ###########################

  tags = {
   env = "demo"
  }
}

##########################################################
# Lambda Function (deploying existing package from local)
##########################################################

module "lambda_function_existing_package_local" {
  source = "terraform-aws-modules/lambda/aws"
 for_each = toset(["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "tweleve", "thirteen", "fourteen","fiveteen"])
  function_name = "${random_pet.this_lambda.id}-lambda-existing-package-local"
  description   = "My awesome lambda function"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  publish       = true

  create_package         = false
  local_existing_package = "C:/Work_Firefly/Demo/terraform-aws-lambda/existing_package.zip"
  #  s3_existing_package = {
  #    bucket = "humane-bear-bucket"
  #    key = "builds/506df8bef5a4fb01883cce3673c9ff0ed88fb52e8583410e0cca7980a72211a0.zip"
  #    version_id = null
  #  }

  layers = [
    module.lambda_layer_local[each.key].lambda_layer_arn,
    module.lambda_layer_s3[each.key].lambda_layer_arn,
  ]
}

#################################
# Lambda Layer (storing locally)
#################################

module "lambda_layer_local" {
  source = "terraform-aws-modules/lambda/aws"
   for_each = toset(["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "tweleve", "thirteen", "fourteen","fiveteen"])
  create_layer = true

  layer_name               = "${each.key}${random_pet.this_lambda.id}-layer-local"
  description              = "My amazing lambda layer (deployed from local)"
  compatible_runtimes      = ["python3.8"]
  compatible_architectures = ["arm64"]

  source_path = "C:/Work_Firefly/Demo/terraform-aws-lambda/hello.py"
}

####################################################
# Lambda Layer with package deploying externally
# (e.g., using separate CI/CD pipeline)
####################################################

module "lambda_layer_with_package_deploying_externally" {
  source = "terraform-aws-modules/lambda/aws"
 for_each = toset(["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "tweleve", "thirteen", "fourteen","fiveteen"])
  create_layer = true

  layer_name          = "${each.key}${random_pet.this_lambda.id}-layer-local"
  description         = "My amazing lambda layer (deployed from local)"
  compatible_runtimes = ["python3.8"]

  create_package         = false
  local_existing_package = "C:/Work_Firefly/Demo/terraform-aws-lambda/existing_package.zip"

  ignore_source_code_hash = true
}

###############################
# Lambda Layer (storing on S3)
###############################

module "lambda_layer_s3" {
  source = "terraform-aws-modules/lambda/aws"
 for_each = toset(["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "tweleve", "thirteen", "fourteen","fiveteen"])
  create_layer = true

  layer_name          = "${random_pet.this_lambda.id}-layer-s3"
  description         = "My amazing lambda layer (deployed from S3)"
  compatible_runtimes = ["python3.8"]

  source_path = "C:/Work_Firefly/Demo/terraform-aws-lambda/hello.py"

  store_on_s3 = true
  s3_bucket   = module.s3_bucket_lambda.s3_bucket_id
}

##############
# Lambda@Edge
##############

module "lambda_at_edge" {
  source = "terraform-aws-modules/lambda/aws"
 for_each = toset(["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "tweleve", "thirteen", "fourteen","fiveteen"])
  lambda_at_edge = true

  function_name = "${each.key}${random_pet.this_lambda.id}-lambda-at-edge"
  description   = "My awesome lambda@edge function"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "C:/Work_Firefly/Demo/terraform-aws-lambda/hello.py"
  hash_extra  = "this string should be included in hash function to produce different filename for the same source" # this is also a build trigger if this changes

  tags = {
   env = "demo"
  }
}

###############################################
# Lambda Function with provisioned concurrency
###############################################

module "lambda_with_provisioned_concurrency" {
  source = "terraform-aws-modules/lambda/aws"
   for_each = toset(["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "tweleve", "thirteen", "fourteen","fiveteen"])

  function_name = "${each.key}${random_pet.this_lambda.id}-lambda-provisioned"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "C:/Work_Firefly/Demo/terraform-aws-lambda/hello.py"
  publish     = true

  hash_extra = "hash-extra-lambda-provisioned"

  provisioned_concurrent_executions = -1 # 2
}

###############################################
# Lambda Function with mixed trusted entities
###############################################

module "lambda_with_mixed_trusted_entities" {
  source = "terraform-aws-modules/lambda/aws"
   for_each = toset(["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "tweleve", "thirteen", "fourteen","fiveteen"])

  function_name = "${each.key}${random_pet.this_lambda.id}-lambda-mixed-trusted-entities"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"

  source_path = "C:/Work_Firefly/Demo/terraform-aws-lambda/hello.py"

  trusted_entities = [
    "appsync.amazonaws.com",
    {
      type = "AWS",
      identifiers = [
        "arn:aws:iam::307990089504:root",
      ]
    },
    {
      type = "Service",
      identifiers = [
        "codedeploy.amazonaws.com",
        "ecs.amazonaws.com"
      ]
    }
  ]
}

##############################
# Lambda Functions + for_each
##############################

module "lambda_function_for_each" {
  source = "terraform-aws-modules/lambda/aws"

  for_each = toset(["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "tweleve", "thirteen", "fourteen","fiveteen"])

  function_name = "my-${each.value}"
  description   = "My awesome lambda function"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  publish       = true

  create_package         = false
  local_existing_package = "C:/Work_Firefly/Demo/terraform-aws-lambda/existing_package.zip"
}

###########
# Disabled
###########

module "disabled_lambda" {
  source = "terraform-aws-modules/lambda/aws"

  create = false
}

##################
# Extra resources
##################

resource "random_pet" "this_lambda" {
  length = 2
}

module "s3_bucket_lambda" {
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket        = "${random_pet.this_lambda.id}-bucket"
  force_destroy = true
}

resource "aws_sqs_queue" "dlq" {
  name = random_pet.this_lambda.id
}