output "ui_public_ips" {
  value       = [for i in aws_instance.ui : i.public_ip]
  description = "Öffentliche IPs der UI-Instanzen"
}

output "alb_dns_name" {
  value       = aws_lb.ui.dns_name
  description = "DNS-Name des Application Load Balancers"
}

output "ui_url" {
  value       = "http://${aws_lb.ui.dns_name}"
  description = "URL von yelb-ui über den ALB (HTTP)"
}
