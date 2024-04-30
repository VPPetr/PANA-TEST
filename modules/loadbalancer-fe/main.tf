terraform {
  required_version = ">= 1.3.0"
}

resource "azurerm_lb_probe" "probe" {
  for_each            = var.ilb-fe_config.probes
  loadbalancer_id     = var.ilb-fe_config.lb-id
  name                = each.key
  protocol            = each.value.protocol
  port                = each.value.port
  request_path        = lookup(each.value, "request_path", null)
  probe_threshold     = lookup(each.value, "probe_threshold", null)
  interval_in_seconds = lookup(each.value, "interval", 5)
  number_of_probes    = lookup(each.value, "number", 2)
}

resource "azurerm_lb_rule" "rule" {
  for_each                       = var.ilb-fe_config.rules
  loadbalancer_id                = var.ilb-fe_config.lb-id
  name                           = each.key
  protocol                       = each.value.protocol
  frontend_port                  = lookup(each.value, "frontend_port", 0)
  backend_port                   = lookup(each.value, "backend_port", 0)
  frontend_ip_configuration_name = var.ilb-fe_config.name
  probe_id                       = azurerm_lb_probe.probe[each.value.probe].id
  backend_address_pool_ids       = [var.ilb-fe_config.pool_id]
  enable_floating_ip             = lookup(each.value, "floating_ip", false)
  idle_timeout_in_minutes        = lookup(each.value, "idle_timeout_in_minutes", null)
  load_distribution              = lookup(each.value, "load_distribution", null)
  disable_outbound_snat          = lookup(each.value, "disable_outbound_snat", null)
  enable_tcp_reset               = lookup(each.value, "enable_tcp_reset", null)
}
