# Configure the AWS Provider  
provider "aws" {  
  region = "us-east-1"  
}

# Define VPC 
resource "aws_vpc" "main" { 
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "ecommerce-vpc"
  }
}

# Define Public Subnets 
resource "aws_subnet" "public_subnet_a" {
  vpc_id            = aws_vpc.main.id 
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id            = aws_vpc.main.id 
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "public-subnet-b"
  }
}

resource "aws_subnet" "public_subnet_c" {
  vpc_id            = aws_vpc.main.id 
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1c"
  
  tags = {
    Name = "public-subnet-c"
  }
}

# Define Private Subnets
resource "aws_subnet" "private_subnet_a" {
  vpc_id            = aws_vpc.main.id 
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "private-subnet-a"
  }
}

resource "aws_subnet" "private_subnet_b" {
  vpc_id            = aws_vpc.main.id 
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "private-subnet-b"
  }
}

resource "aws_subnet" "private_subnet_c" {
  vpc_id            = aws_vpc.main.id 
  cidr_block        = "10.0.6.0/24"
  availability_zone = "us-east-1c"
  
  tags = {
    Name = "private-subnet-c"
  }
}

