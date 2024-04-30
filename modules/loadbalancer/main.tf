terraform {
  required_version = ">= 1.3.0"
}

resource "azurerm_lb" "lb" {
  name                = var.ilb_config.name
  location            = var.ilb_config.location
  resource_group_name = var.ilb_config.resource_group_name
  sku                 = lookup(var.ilb_config, "sku", "Standard")
  tags                = lookup(var.ilb_config, "tags", null)

  dynamic "frontend_ip_configuration" {
    for_each = var.ilb_config.frontend
    content {
      name                          = frontend_ip_configuration.value.name
      subnet_id                     = var.ilb_config.subnet_id
      private_ip_address            = frontend_ip_configuration.value.ip
      private_ip_address_allocation = "Static"
      zones                         = lookup(frontend_ip_configuration.value, "zones", null)
    }
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

module "backend" {
  source   = "../loadbalancer-be"
  for_each = var.ilb_config.backend_pool
  ilb-be_config = merge(each.value, {
    lb-id = azurerm_lb.lb.id
    name  = each.key
  })
}

module "frontend" {
  source   = "../loadbalancer-fe"
  for_each = var.ilb_config.frontend
  ilb-fe_config = merge(each.value, {
    lb-id   = azurerm_lb.lb.id
    pool_id = module.backend[each.value.backend_pool_name].id
  })
}

