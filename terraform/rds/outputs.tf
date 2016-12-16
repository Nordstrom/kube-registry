output "address" {
    value = "${aws_db_instance.portus.address}"
}

output "endpoint" {
    value = "${aws_db_instance.portus.endpoint}"
}

output "username" {
    value = "${aws_db_instance.portus.username}"
}

output "password" {
    value = "${aws_db_instance.portus.password}"
}
