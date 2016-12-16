provider "mysql" {
    endpoint = "${var.mysql_endpoint}"
    username = "${var.master_username}"
    password = "${var.master_password}"
}

resource "mysql_database" "portus" {
    name = "${var.db_name}"
}

resource "mysql_user" "portus" {
    user = "${var.db_username}"
    host = "172.%.%.%"
    password = "${var.db_password}"
}

resource "mysql_grant" "portus" {
    user = "${mysql_user.portus.user}"
    host = "${mysql_user.portus.host}"
    database = "${mysql_database.portus.name}"
    privileges = ["ALL"]
}
