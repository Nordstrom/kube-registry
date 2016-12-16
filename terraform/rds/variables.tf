variable "aws_region" {}
variable "vpc_id" {}

variable "cost_center" {}
variable "cloud_team_id" {}

variable "aws_resource_name_prefix" {}

variable "instance_name" {}
variable "master_db_username" {}
variable "master_db_password" {}

variable "db_instances_subnet_id_list" { type = "list" }
variable "rds_security_group_allowed_ingress_cidr_ranges" { type = "list" }
