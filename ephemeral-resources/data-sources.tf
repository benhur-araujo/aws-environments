data "aws_vpc" "master-vpc" {
  filter {
    name = "tag:Name"
    values = ["${var.project}-vpc"]
  }
}

data "aws_subnets" "master-subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.master-vpc.id]
  }
  depends_on = [ data.aws_vpc.master-vpc ]
}