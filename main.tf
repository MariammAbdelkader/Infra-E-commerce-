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


