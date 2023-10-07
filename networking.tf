# Default VPC for "Platform-Master" Project
resource "aws_vpc" "master-vpc" {
  cidr_block = "172.20.0.0/16"
  instance_tenancy = "default"

  ### https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html#vpc-dns-support
  ### https://docs.aws.amazon.com/vpc/latest/userguide/vpc-dns.html#AmazonDNS
  enable_dns_hostnames = true      # Assign Public DNS hostname to instances with public IPs
  enable_dns_support = true        # DNS resolution through the Amazon provided DNS server (DNS Resolver service which is built into each availability zone within an AWS Region)
  ###
  tags = {
    Name = "${var.project}-vpc"
  }
}

# Internet Gateway allow communication between VPC x Internet
# https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html
resource "aws_internet_gateway" "master-igw" {
  vpc_id = aws_vpc.master-vpc.id
  
  tags = {
    Name = "${var.project}-igw"
  }
}

# Public Subnet Route Table
resource "aws_route_table" "master-rt" {
  vpc_id = aws_vpc.master-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.master-igw.id
  }

  tags = {
    Name = "${var.project}-master-rt"
  }
}

# Create two subnets at differents AZs
resource "aws_subnet" "master-subnets-public" {
  for_each = local.availability_zones
  vpc_id = aws_vpc.master-vpc.id
  cidr_block = "172.20.${index(values(local.availability_zones), "${each.value}")}.0/24"
  availability_zone = each.value

  tags = {
    Name = "${var.project}-subnet-public"
  }
}

# Attach Internet Route Table to the Subnets, so they become Public Subnets
resource "aws_route_table_association" "master-rt-association" {
  for_each = local.availability_zones
  subnet_id      = aws_subnet.master-subnets-public[each.key].id
  route_table_id = aws_route_table.master-rt.id
}
