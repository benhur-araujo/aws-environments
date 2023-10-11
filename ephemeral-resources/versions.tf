terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.19.0"
    }
  }
  backend "s3" {
    bucket = "platform-master"
    key    = "tf-states/aws-environments/ephemeral-resources/terraform.tfstate"
    region = "eu-north-1"
  }
}

provider "aws" {
  region = "eu-north-1"
  default_tags {
    tags = {
      project        = var.project
      owner          = "Benhur A. Silva"
      owner-linkedin = "linkedin.com/in/benhuraraujo/"
    }
  }
}