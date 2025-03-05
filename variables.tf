variable "db_username" {
  description = "The master username for RDS"
  type        = string
}

variable "db_password" {
  description = "The master password for RDS"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "The name of the database"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
