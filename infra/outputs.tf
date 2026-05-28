output "cloudfront_url" {
  value = "https://${module.cloudfront.cloudfront_domain_name}"
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "ec2_public_ip" {
  value = module.ec2.public_ip
}

output "rds_endpoint" {
  value = module.rds.endpoint
}