output "blue_lb_dns" {
  value = aws_lb.blue_lb.dns_name
}

output "green_lb_dns" {
  value = aws_lb.green_lb.dns_name
}


