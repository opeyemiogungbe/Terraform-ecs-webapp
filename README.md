# 🐳 Terraform AWS ECS WebApp Deployment

This project demonstrates how to deploy a containerized Node.js web application to **Amazon ECS** (Elastic Container Service) using **Docker** and **Terraform**, following modern DevOps best practices.

---

## 📦 Project Structure

```
terraform-ecs-webapp/
├── app/                     # Node.js web application
│   ├── package.json
│   └── server.js
├── dockerfile               # Dockerfile for building the app container
├── terraform.tfvars         # Environment-specific input values
├── variable.tf              # All input variables
├── output.tf                # Output values (e.g. load balancer URL)
├── main.tf                  # Root Terraform module
├── modules/                 # Terraform modules
│   ├── vpc/                 # VPC, subnets, internet gateway
│   ├── sg/                  # Security groups
│   ├── iam/                 # IAM roles and policies
│   ├── ecs/                 # ECS cluster, service, task definition
│   └── ecr/                 # (optional) ECR repo for image storage
```

---

## 🌍 What This Project Does

* Builds a **Docker image** from your Node.js app
* Creates an **ECS cluster**
* Defines a **task definition** and **service**
* Provisions required **IAM roles** and **policies**
* Deploys the containerized app to ECS (Fargate)
* Makes the app accessible via a public IP

---

## 🧰 Prerequisites

* Docker Desktop (with virtualization enabled)
* AWS CLI configured (`aws configure`)
* Terraform installed
* An IAM user with permissions for:

  * `iam:*`
  * `ecs:*`
  * `ecr:*` (optional)
  * `ec2:*` (for networking)

---

## ⚙️ STEPS

### 1. Clone the Repo

we cloned our repo and start work in our folder

```bash
git clone https://github.com/yourusername/terraform-ecs-webapp.git
cd terraform-ecs-webapp
```

### 2. Building our Terraform modular structures and it's necessary code

🔹 modules/vpc/Main.tf

Creates a Virtual Private Cloud, subnets, internet gateway and route tables.

```
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = element(var.azs, count.index)
  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

🔹 modules/vpc/Variable.tf

```
variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  type        = list(string)
}

variable "azs" {
  description = "Availability zones for the subnets"
  type        = list(string)
}
```

🔹 modules/vpc/outputs.tf

```
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
```
🔹 modules/sg/Main.tf

Configures security groups for ECS tasks.

```
resource "aws_security_group" "ecs_sg" {
  name        = "${var.project_name}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ecs-sg" }
}
```
🔹 modules/sg/Variable.tf

```
variable "project_name" {}
variable "vpc_id" {}
```
🔹 modules/sg/outputs.tf

```
output "ecs_sg_id" {
  value = aws_security_group.ecs_sg.id
}
```

🔹 modules/iam/Main.tf

```
resource "aws_iam_role" "ecs_task_exec_role" {
  name = "${var.project_name}-ecs-task-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_exec_policy" {
  role       = aws_iam_role.ecs_task_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
```
🔹 modules/iam/Variable.tf

```
variable "project_name" {}
```

🔹 modules/iam/Output.tf

```
output "ecs_task_exec_role_arn" {
  value = aws_iam_role.ecs_task_exec_role.arn
}
```

🔹modules/ecs/Main.tf

Defines the ECS cluster, task definition, and ECS service.

```
resource "aws_ecs_cluster" "this" {
  name = "${var.project_name}-cluster"
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.task_exec_role_arn

  container_definitions = jsonencode([
    {
      name  = "web"
      image = var.image_url
      portMappings = [{ containerPort = 3000 }]
    }
  ])
}

resource "aws_ecs_service" "this" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [var.sg_id]
    assign_public_ip = true
  }
}
```

🔹modules/ecs/Variable.tf

```
variable "project_name" {}
variable "subnet_ids" {
  type = list(string)
}
variable "sg_id" {}
variable "task_exec_role_arn" {}
variable "image_url" {}
```

🔹modules/ecs/Outputs.tf

```
output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}
```

🔹 modules/ecr/main.tf

```
resource "aws_ecr_repository" "this" {
  name                 = "${var.project_name}-repo"
  image_tag_mutability = "MUTABLE"
}
```

🔹 modules/ecr/Variable.tf

```
variable "project_name" {}
```

🔹 modules/ecr/Outputs.tf

```
output "ecr_repo_url" {
  value = aws_ecr_repository.this.repository_url
}
```
🔹 Root/Main.tf

```
provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source              = "./modules/vpc"
  project_name        = "webapp"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  azs                 = ["us-east-1a", "us-east-1b"]
}

module "sg" {
  source       = "./modules/sg"
  project_name = "webapp"
  vpc_id       = module.vpc.vpc_id
}

module "iam" {
  source       = "./modules/iam"
  project_name = "webapp"
}

module "ecr" {
  source       = "./modules/ecr"
  project_name = "webapp"
}

module "ecs" {
  source            = "./modules/ecs"
  project_name      = "webapp"
  subnet_ids        = module.vpc.public_subnet_ids
  sg_id             = module.sg.ecs_sg_id
  task_exec_role_arn = module.iam.ecs_task_exec_role_arn
  image_url         = "${module.ecr.ecr_repo_url}:latest"
}
```

🔹 Root/terraform.tfvars

```
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
```
### 3. Build docker image and docker file..

Dockerfile
```
Dockerfile
FROM node:18

WORKDIR /usr/src/app

COPY app/package*.json ./
RUN npm install

COPY app/ .

EXPOSE 3000
CMD ["npm", "start"]
```
Now let's build our Docker image locally using Docker Desktop to see if it works before running our Terraform to deploy the image to ECR

```
docker build -t ecs-webapp .
docker run -p 3000:3000 ecs-webapp
```

### 3. Initialize Terraform

```
terraform init
terraform plan
```


### 5. Deploy to AWS

```
terraform apply
```




---

## ✅ Output





## 🪩 Teardown

To destroy all AWS resources:

```bash
terraform destroy
```

---

## 📖 What You Learned

* Infrastructure as Code (Terraform)
* Docker image packaging
* AWS ECS and IAM automation
* Secure, repeatable deployments



