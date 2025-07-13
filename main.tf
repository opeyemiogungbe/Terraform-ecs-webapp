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
