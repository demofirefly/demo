resource "aws_subnet" "a4-demo-public-eu-west-1c-9bd" {
  cidr_block                          = "20.23.13.0/24"
  map_public_ip_on_launch             = true
  private_dns_hostname_type_on_launch = "ip-name"
  tags = {
    Environment = "demo"
    Name        = "a4-demo-public-eu-west-1c"
  }
  vpc_id = "${data.aws_vpc.a4-demo-94b.id}"
}




data "aws_vpc" "a4-demo-94b" {
  id = "vpc-0507d25e6a7164abd"
}

