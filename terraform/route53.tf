# Route 53 DNS Configuration (optional)
# Uncomment and configure if you have a domain

# # Hosted Zone (create new or import existing)
# resource "aws_route53_zone" "main" {
#   count = var.create_route53_zone ? 1 : 0
#   name  = var.domain_name

#   tags = {
#     Name = "${var.project_name}-${var.environment}-zone"
#   }
# }

# # A Record pointing to EC2 instance
# resource "aws_route53_record" "openremote" {
#   count   = var.domain_name != "" ? 1 : 0
#   zone_id = var.create_route53_zone ? aws_route53_zone.main[0].zone_id : var.route53_zone_id
#   name    = var.domain_name
#   type    = "A"
#   ttl     = 300
#   records = [aws_eip.openremote.public_ip]
# }

# # CNAME for www subdomain
# resource "aws_route53_record" "www" {
#   count   = var.domain_name != "" ? 1 : 0
#   zone_id = var.create_route53_zone ? aws_route53_zone.main[0].zone_id : var.route53_zone_id
#   name    = "www.${var.domain_name}"
#   type    = "CNAME"
#   ttl     = 300
#   records = [var.domain_name]
# }

# # To use Route 53, uncomment the above and add to terraform.tfvars:
# # domain_name = "your-domain.com"
# # create_route53_zone = true  # or false if zone already exists
# # route53_zone_id = "Z123456789ABC"  # if using existing zone

