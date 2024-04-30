terraform {
  required_version = ">= 1.3.0"
}

resource "azurerm_route_table" "route" {
  name                          = var.route_table_config.name
  location                      = var.route_table_config.location
  resource_group_name           = var.route_table_config.resource_group_name
  disable_bgp_route_propagation = true
  tags                          = lookup(var.route_table_config, "tags", null)

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_route" "route" {
  for_each               = var.route_table_config.routes
  name                   = each.key
  resource_group_name    = var.route_table_config.resource_group_name
  route_table_name       = azurerm_route_table.route.name
  address_prefix         = each.value.prefix
  next_hop_type          = each.value.next_hop_type
  next_hop_in_ip_address = lookup(each.value, "next_hop_ip", null)
}

output "name" {
  value = var.route_table_config.name
}

output "id" {
  value = azurerm_route_table.route.id
}
