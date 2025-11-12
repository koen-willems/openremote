resource "aws_route53_zone" "main" {
  count = var.create_route53_zone ? 1 : 0
  name  = var.domain_name

  tags = {
    Name = "${var.project_name}-${var.environment}-zone"
  }
}

resource "aws_route53_record" "openremote_service" {
  count = var.service_hostname != "" && (var.create_route53_zone || var.route53_zone_id != "") ? 1 : 0

  zone_id = var.create_route53_zone ? aws_route53_zone.main[0].zone_id : var.route53_zone_id
  name    = var.service_hostname
  type    = "A"
  ttl     = 300
  records = [aws_eip.openremote.public_ip]
}

