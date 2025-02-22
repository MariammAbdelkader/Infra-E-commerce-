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

# Frontend Security Group (Allows HTTP/HTTPS)
resource "aws_security_group" "frontend_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP access from anywhere
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTPS access from anywhere
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH access from any where "insecure"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }

  tags = {
    Name = "frontend-sg"
  }
}

# Load Balancer Security Group (Handles External Traffic)
resource "aws_security_group" "lb_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP from anywhere
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTPS from anywhere
  }

  egress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id] # Allow traffic to backend
  }

  tags = {
    Name = "load-balancer-sg"
  }
}

# Backend Security Group (Handles API Requests)
resource "aws_security_group" "backend_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.lb_sg.id] # Only allow traffic from Load Balancer
  }

  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.database_sg.id] # Allow outbound traffic to database
  }

  egress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.ai_sg.id] # Allow outbound traffic to AI services
  }

  tags = {
    Name = "backend-sg"
  }
}

# Database Security Group (Only Accessible by Backend)
resource "aws_security_group" "database_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id] # Allow only backend servers to access DB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound traffic 
  }

  tags = {
    Name = "database-sg"
  }
}
#determine how to handle AI services
# AI Services Security Group (For AI-Related Processing)
resource "aws_security_group" "ai_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id] # Allow backend to communicate with AI services
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound traffic if needed
  }

  tags = {
    Name = "ai-services-sg"
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
resource "aws_db_instance" "postgres_db" {
  identifier           = "ecommerce-postgres-db"
  engine              = "postgres"
  engine_version      = "15.4"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  storage_type        = "gp3"

  db_name             = "ecommerce_db"
  username           = "admin"
  password           =  "GPasu2025"  
  parameter_group_name = "default.postgres15"
  
  db_subnet_group_name  = aws_db_subnet_group.database_subnet_group.name
  vpc_security_group_ids = [aws_security_group.database_sg.id]

  multi_az             = false
  publicly_accessible  = false
  skip_final_snapshot  = true

  tags = {
    Name = "ecommerce-postgres-db"
  }
}

# Create S3 Bucket for Frontend Hosting
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "ecommerce-frontend-bucket"
  
  tags = {
    Name = "ecommerce-frontend"
    Environment = "Production"
  }
}

# Set Public Access Block 
resource "aws_s3_bucket_public_access_block" "frontend_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# -------------------------------
# Application Load Balancer (ALB)
# -------------------------------
resource "aws_lb" "app_alb" {
  name               = "ecommerce-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets           = [aws_subnet.load_balancer_subnet.id, aws_subnet.frontend_subnet.id]
  enable_deletion_protection = false
  tags = {
    Name = "ecommerce-alb"
  }
}

# -------------------------------
# ALB Listener
# -------------------------------
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}
