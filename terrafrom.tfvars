project_name         = "ecs-webapp"
region               = "us-east-1"

# VPC configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

# ECS cluster settings
ecs_cluster_name     = "ecs-webapp-cluster"
container_name       = "webapp"
container_port       = 3000

# ECR configuration
ecr_repo_name        = "ecs-webapp"

# Security Group
allowed_ports        = [3000]

# Docker image tag
image_tag            = "latest"
