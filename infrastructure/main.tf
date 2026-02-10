# --------------------------
# Variables
# --------------------------
variable "aws_region" {
  description = "AWS region"
  default     = "eu-central-1"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  default     = "ami-01f79b1e4a5c64257"  # Ubuntu linux, eu-central-1
}

variable "instance_type" {
  default = "t3.micro"
}

variable "key_name" {
  description = "Your EC2 key pair name for SSH access"
  default     = "terraform-keys" 
}


# --------------------------
# Terraform & Provider
# --------------------------
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }
  backend "s3"{
    bucket = "terraform-state-bucket-97da5e70"
    key    = "terraform.tfstate"
    region = "eu-central-1"
    dynamodb_table = "terraform-state-locking"
    encrypt = true
  }

  required_version = ">= 1.2"
}

provider "aws" {
  region = var.aws_region
}



# --------------------------
# Security Group
# --------------------------
resource "aws_security_group" "example_sg" {
  name        = "example-sg"
  description = "Allow SSH, HTTP, and HTTPS inbound traffic"

  # SSH open to anyone
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "example-sg"
  }
}

# --------------------------
# EC2 Instance
# --------------------------
resource "aws_instance" "example_instance" {
  ami           = var.ami_id
  instance_type = var.instance_type
 # key_name      = var.key_name

  # Attach the security group
  vpc_security_group_ids = [aws_security_group.example_sg.id]

  tags = {
    Name = "ExampleInstance"
  }
}

