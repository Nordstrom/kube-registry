output "username" {
    value = "${mysql_user.portus.user}"
}

output "password" {
    value = "${mysql_user.portus.password}"
}
