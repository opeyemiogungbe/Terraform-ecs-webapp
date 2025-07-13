resource "aws_ecr_repository" "this" {
  name                 = "${var.project_name}-repo"
  image_tag_mutability = "MUTABLE"
}

