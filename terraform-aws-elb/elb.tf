
resource "random_pet" "this_elb" {
  length = 2
}

    provider "aws" {
  region = "eu-central-1"
} 


##############################################################
# Data sources to get VPC, subnets anyesd security group details
##############################################################

data "aws_vpc" "default_vpc_elb" {
   id = "vpc-0b9061499d542544e"
}


data "aws_subnet_ids" "all_elb" {
  vpc_id = data.aws_vpc.default_vpc_elb.id
}

data "aws_security_group" "default_elb_sg" {
  vpc_id = data.aws_vpc.default_vpc_elb.id
  name   = "default"
}

#########################
# S3 bucket for ELB logs
#########################
data "aws_elb_service_account" "this_elb_service" {}

resource "aws_s3_bucket" "logs_elb_s3" {
  bucket        = "elb-logs-${random_pet.this_elb.id}"
  acl           = "private"
  policy        = data.aws_iam_policy_document.logs_elb.json
  force_destroy = true
}

data "aws_iam_policy_document" "logs_elb" {
  statement {
    actions = [
      "s3:PutObject",
    ]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.this_elb_service.arn]
    }

    resources = [
      "arn:aws:s3:::elb-logs-${random_pet.this_elb.id}/*",
    ]
  }
}

##################
# ACM certificate
##################
resource "aws_route53_zone" "this_elb" {
  name          = "elbexample.com"
  force_destroy = true
}

module "acm_elb" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 3.0"

  zone_id = aws_route53_zone.this_elb.zone_id

  domain_name               = "elbexample.com"
  subject_alternative_names = ["*.elbexample.com"]

  wait_for_validation = false
}

######
# ELB
######
module "elb_elb" {
  source = "terraform-aws-modules/elb/aws"
  for_each = toset(["1", "2", "3","4","5","6","7","8","9","10"])
  name = "elb-${each.key}-demo"

  subnets         = data.aws_subnet_ids.all_elb.ids
  security_groups = [data.aws_security_group.default_elb_sg.id]
  internal        = false

  listener = [
    {
      instance_port     = "80"
      instance_protocol = "http"
      lb_port           = "80"
      lb_protocol       = "http"
    },
    {
      instance_port     = "8080"
      instance_protocol = "http"
      lb_port           = "8080"
      lb_protocol       = "http"

      #            Note about SSL:
      #            This line is commented out because ACM certificate has to be "Active" (validated and verified by AWS, but Route53 zone used in this example is not real).
      #            To enable SSL in ELB: uncomment this line, set "wait_for_validation = true" in ACM module and make sure that instance_protocol and lb_protocol are https or ssl.
      #            ssl_certificate_id = module.acm.acm_certificate_arn
    },
  ]

  health_check = {
    target              = "HTTP:80/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  access_logs = {
    bucket = aws_s3_bucket.logs_elb_s3.id
  }

  tags = {

    Environment = "demo"
  }

  # ELB attachments
  number_of_instances = var.number_of_instances
  instances           = module.ec2_instances_elb.id
}

################
# EC2 instances
################
module "ec2_instances_elb" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  instance_count = var.number_of_instances

  name                        = "my-app"
  ami                         = "ami-05ff5eaef6149df49"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [data.aws_security_group.default_elb_sg.id]
  subnet_id                   = element(tolist(data.aws_subnet_ids.all_elb.ids), 0)
  associate_public_ip_address = true
}