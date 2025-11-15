locals {
  cloudflare_dns_enabled = (
    var.use_cloudflare_dns &&
    var.service_hostname != "" &&
    var.cloudflare_zone_id != ""
  )

  cloudflare_record_name = local.cloudflare_dns_enabled ? (
    var.service_hostname == var.domain_name
    ? "@"
    : replace(var.service_hostname, format(".%s", var.domain_name), "")
  ) : ""
}

resource "cloudflare_record" "openremote" {
  count   = local.cloudflare_dns_enabled ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = local.cloudflare_record_name == "" ? var.service_hostname : local.cloudflare_record_name
  type    = "A"
  value   = aws_eip.openremote.public_ip
  ttl     = var.cloudflare_dns_ttl
  proxied = false
}
