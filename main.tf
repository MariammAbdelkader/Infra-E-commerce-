# -------------------------------
# Configure AWS Provider
# -------------------------------
provider "aws" {
  region = "us-east-1"
}

# -------------------------------
# Define VPC
# -------------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "ecommerce-vpc"
  }
}

# -------------------------------
# Define Public Subnets
# -------------------------------
resource "aws_subnet" "frontend_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "frontend-subnet"
  }
}

resource "aws_subnet" "load_balancer_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "load-balancer-subnet"
  }
}

resource "aws_subnet" "nat_gateway_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "nat-gateway-subnet"
  }
}

# -------------------------------
# Define Private Subnets
# -------------------------------
resource "aws_subnet" "ai_services_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "ai-services-subnet"
  }
}

resource "aws_subnet" "database_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "database-subnet"
  }
}

resource "aws_subnet" "backend_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "us-east-1c"

  tags = {
    Name = "backend-subnet"
  }
}

# -------------------------------
# Define Internet Gateway
# -------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-gateway"
  }
}

# -------------------------------
# Public Route Table
# -------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate Public Subnets with Public Route Table
resource "aws_route_table_association" "frontend" {
  subnet_id      = aws_subnet.frontend_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "load_balancer" {
  subnet_id      = aws_subnet.load_balancer_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "nat_gateway" {
  subnet_id      = aws_subnet.nat_gateway_subnet.id
  route_table_id = aws_route_table.public.id
}

# -------------------------------
# NAT Gateway for Private Subnets
# -------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.nat_gateway_subnet.id

  tags = {
    Name = "nat-gateway"
  }
}

# -------------------------------
# Private Route Table
# -------------------------------
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

# Associate Private Subnets with Private Route Table
resource "aws_route_table_association" "ai_services" {
  subnet_id      = aws_subnet.ai_services_subnet.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "database" {
  subnet_id      = aws_subnet.database_subnet.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "backend" {
  subnet_id      = aws_subnet.backend_subnet.id
  route_table_id = aws_route_table.private.id
}

# -------------------------------
# Security Groups
# -------------------------------
resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

resource "aws_security_group" "database_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "database-sg"
  }
}

# -------------------------------
# Database Subnet Group
# -------------------------------
resource "aws_db_subnet_group" "database_subnet_group" {
  name       = "database-subnet-group"
  subnet_ids = [aws_subnet.database_subnet.id, aws_subnet.backend_subnet.id]

  tags = {
    Name = "database-subnet-group"
  }
}

# -------------------------------
# PostgreSQL RDS Instance
# -------------------------------
