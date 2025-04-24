# Configure AWS Provider
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

# Define Private Subnets
resource "aws_subnet" "ai_services_subnet" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "ai-services-subnet"
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

# Define Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-gateway"
  }
}

# Public Route Table
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

# NAT Gateway for Private Subnets
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
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.ai_sg.id] # Allow outbound traffic to AI services
  }
  //for database image
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic (for container to pull images, etc.)
  }

  tags = {
    Name = "backend-sg"
  }
}

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

# NAT Gateway Security Group (Provides Internet Access to Private Subnets)
resource "aws_security_group" "nat_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"] # Allow internal VPC traffic
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound internet access
  }

  tags = {
    Name = "nat-gateway-sg"
  }
}

# Create S3 Bucket for Frontend Hosting
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "ecommerce-frontend-bucket"
  
  tags = {
    Name        = "ecommerce-frontend"
    Environment = "Production"
  }
}

# Set Public Access Block - Restrict Public Access (For CloudFront)
resource "aws_s3_bucket_public_access_block" "frontend_public_access" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable Static Website Hosting
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Create CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "Frontend-OAC"
  description                       = "Origin Access Control for Frontend S3 Bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                   = "sigv4"
}

# Create an S3 Bucket Policy Allowing CloudFront to Access S3
resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "cloudfront.amazonaws.com"
      },
      Action = "s3:GetObject",
      Resource = "${aws_s3_bucket.frontend_bucket.arn}/*",
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend_distribution.arn
        }
      }
    }]
  })
}

# Create CloudFront Distribution for Frontend
resource "aws_cloudfront_distribution" "frontend_distribution" {
  origin {
    domain_name              = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_id                = "FrontendS3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "FrontendS3Origin"

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    # Use a managed cache policy for modern configurations
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6" # Managed-CachingOptimized
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name        = "ecommerce-frontend-cdn"
    Environment = "Production"
    
  }
}

# -------------------------------
# Application Load Balancer (ALB)
# -------------------------------
resource "aws_lb" "app_alb" {
  name               = "ecommerce-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets           = [aws_subnet.load_balancer_subnet.id, aws_subnet.frontend_subnet.id]
  enable_deletion_protection = false
  tags = {
    Name = "ecommerce-alb"
  }
}
# ALB Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}
# Target Group for Backend
resource "aws_lb_target_group" "backend_tg" {
  name     = "backend-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# -------------------------------
# Backend EC2 Instance
# -------------------------------
#resource "aws_instance" "backend_instance" {
  #ami           = "ami-0c55b159cbfafe1f0"  # Replace with the latest Amazon Linux AMI or your preferred OS
 # instance_type = "t3.micro"
 # subnet_id     = aws_subnet.backend_subnet.id
 # security_groups = [aws_security_group.backend_sg.id]

 # tags = {
 #   Name = "backend-instance"
 # }
#}

# -------------------------------
# AI Services EC2 Instance
# -------------------------------
resource "aws_instance" "ai_instance" {
  ami           = "ami-0c55b159cbfafe1f0"  # Replace with the latest AMI
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.ai_services_subnet.id
  security_groups = [aws_security_group.ai_sg.id]

  tags = {
    Name = "ai-instance"
  }
}

# -------------------------------
# Attach Backend Instances to Target Group
# -------------------------------
#resource "aws_lb_target_group_attachment" "backend_instance" {
 # count            = length(aws_instance.backend)
  #target_group_arn = aws_lb_target_group.backend_tg.arn
  #target_id        = aws_instance.backend[count.index].id
  #port             = 80
#}

# Launch Template defines the instance configuration for Auto Scaling
resource "aws_launch_template" "backend_lt" {
  name          = "backend-launch-template"
  image_id      = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  user_data = base64encode(<<EOF
    #!/bin/bash
    sudo yum update -y
    # Add startup scripts (e.g., install Docker, start app, etc.)
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "backend-instance"
    }
  }
}
#An Auto Scaling Group (ASG)
resource "aws_autoscaling_group" "backend_asg" {
  desired_capacity     = 1
  min_size            = 1
  max_size            = 3
  vpc_zone_identifier = [aws_subnet.backend_subnet.id]  # Private Subnet
  target_group_arns   = [aws_lb_target_group.backend_tg.arn]

  launch_template {
    id      = aws_launch_template.backend_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "backend-instance"
    propagate_at_launch = true
  }
}

#Scale Out (Increase Instances when CPU > 70%)
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 60
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
}

#Scale In (Decrease Instances when CPU < 30%)
resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in-policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = 60
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
}


resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "high-cpu-backend"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace          = "AWS/EC2"
  period             = 60
  statistic          = "Average"
  threshold          = 70
  alarm_actions      = [aws_autoscaling_policy.scale_out.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.backend_asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "low-cpu-backend"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace          = "AWS/EC2"
  period             = 60
  statistic          = "Average"
  threshold          = 30
  alarm_actions      = [aws_autoscaling_policy.scale_in.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.backend_asg.name
  }
}


