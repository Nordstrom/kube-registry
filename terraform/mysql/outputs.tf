output "database" {
    value = "${var.db_name}"
}

output "username" {
    value = "${mysql_user.portus.user}"
}

output "password" {
    value = "${mysql_user.portus.password}"
}
