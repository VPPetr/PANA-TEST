terraform {
  required_version = ">= 1.3.0"
}

resource "azurerm_lb_backend_address_pool" "pool" {
  loadbalancer_id = var.ilb-be_config.lb-id
  name            = var.ilb-be_config.name
}

resource "azurerm_network_interface_backend_address_pool_association" "association" {
  for_each                = var.ilb-be_config.members
  network_interface_id    = each.value.nic_id
  ip_configuration_name   = each.value.ip_name
  backend_address_pool_id = azurerm_lb_backend_address_pool.pool.id
}

output "id" {
  value = azurerm_lb_backend_address_pool.pool.id
}
