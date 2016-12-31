provider "aws" {
    region = "${var.aws_region}"
}

resource "aws_db_instance" "portus" {
    identifier             = "${var.aws_resource_name_prefix}-${var.instance_name}"
    engine                 = "mariadb"
    engine_version         = "10.1.14"
    instance_class         = "db.t2.micro"
    port                   = 3306
    username               = "${var.master_db_username}"
    password               = "${var.master_db_password}"
    storage_type           = "gp2"
    allocated_storage      = "5"
    multi_az               = true
    copy_tags_to_snapshot  = true
    db_subnet_group_name   = "${aws_db_subnet_group.portus.name}"
    vpc_security_group_ids = [ "${aws_security_group.rds_instances.id}" ]
    parameter_group_name   = "${aws_db_parameter_group.portus.name}"

    tags {
        Name = "${var.aws_resource_name_prefix}-${var.instance_name}"
        CostCenter = "${var.cost_center}"
        Owner = "${var.cloud_team_id}"
    }
}

resource "aws_db_subnet_group" "portus" {
    name = "${var.aws_resource_name_prefix}-${var.instance_name}-subnets"
    description = "Portus UI and Auth for docker registry"
    subnet_ids = "${var.db_instances_subnet_id_list}"

    tags {
      Name = "${var.instance_name}"
      CostCenter = "${var.cost_center}"
      Owner = "${var.cloud_team_id}"
    }
}

resource "aws_security_group" "rds_instances" {
    name = "${var.aws_resource_name_prefix}-${var.instance_name}"
    description = "Portus UI and Auth for docker registry"
    vpc_id = "${var.vpc_id}"

    tags {
        Name = "${var.aws_resource_name_prefix}-${var.instance_name}"
        CostCenter = "${var.cost_center}"
        Owner = "${var.cloud_team_id}"
    }
}

resource "aws_security_group_rule" "rds_instances_allow_mysql_ingress_from_networks" {
    type = "ingress"
    from_port = 3306
    to_port = 3306
    protocol = "tcp"

    security_group_id = "${aws_security_group.rds_instances.id}"
    cidr_blocks = "${var.rds_security_group_allowed_ingress_cidr_ranges}"
}

resource "aws_security_group_rule" "rds_instances_allow_egress_to_anywhere" {
    type = "egress"
    from_port = 0
    to_port = 0
    protocol = "-1"

    security_group_id = "${aws_security_group.rds_instances.id}"
    cidr_blocks = [ "0.0.0.0/0" ]
}

resource "aws_db_parameter_group" "portus" {
    name = "${var.aws_resource_name_prefix}-${var.instance_name}"
    family = "mariadb10.1"
    description = "Database for Portus"

    parameter {
      name = "max_connections"
      value = "256"
      apply_method = "pending-reboot"
    }

    tags {
        Name = "${var.instance_name}"
        CostCenter = "${var.cost_center}"
        Owner = "${var.cloud_team_id}"
    }
}
