variable "project_name" {}
variable "subnet_ids" {
  type = list(string)
}
variable "sg_id" {}
variable "task_exec_role_arn" {}
variable "image_url" {}
