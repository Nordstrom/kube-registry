provider "aws" {
    region = "${var.aws_region}"
}

resource "aws_iam_role" "docker_registry" {
    name = "${var.aws_resource_name_prefix}-docker_registry"
    path = "/${var.cloud_team_id}/k8s/"
    assume_role_policy = "${file("${var.build_dir}/assume_role_policy.json")}"
}

resource "aws_iam_role_policy" "docker_registry" {
    name = "allow_manage_docker_registry_content_in_team_s3_bucket"
    # description = "Permissions related to running the Docker Registry"
    role = "${aws_iam_role.docker_registry.id}"
    policy = "${file("${var.build_dir}/iam_role_policy.json")}"
}
