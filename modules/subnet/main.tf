terraform {
  required_version = ">= 1.3.0"
}

resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_config.name
  resource_group_name  = var.subnet_config.resource_group_name
  virtual_network_name = var.subnet_config.virtual_network_name
  address_prefixes     = ["${var.subnet_config.prefix}"]
  service_endpoints    = lookup(var.subnet_config, "service_endpoints", [])
}

locals {
  nsg_config   = lookup(var.subnet_config, "nsg", {})
  nsg_rules    = lookup(local.nsg_config, "rules", {})
  nfl_settings = lookup(local.nsg_config, "nfl", {})
}

resource "azurerm_network_security_group" "nsg" {
  count               = local.nsg_config == {} ? 0 : 1
  name                = lookup(local.nsg_config, "name", "DefaultNSGName")
  location            = var.subnet_config.location
  resource_group_name = var.subnet_config.resource_group_name
  tags                = lookup(var.subnet_config, "tags", null) 
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_network_security_rule" "nsgrules" {
  depends_on                                 = [azurerm_network_security_group.nsg]
  for_each                                   = local.nsg_rules
  name                                       = each.key
  resource_group_name                        = var.subnet_config.resource_group_name
  network_security_group_name                = lookup(local.nsg_config, "name", "DefaultNSGName")
  access                                     = lookup(each.value, "access", null)
  priority                                   = lookup(each.value, "priority", null)
  direction                                  = lookup(each.value, "direction", null)
  protocol                                   = lookup(each.value, "protocol", null)
  description                                = lookup(each.value, "description", null)
  source_port_range                          = lookup(each.value, "source_port_range", null)
  source_port_ranges                         = lookup(each.value, "source_port_ranges", null)
  destination_port_range                     = lookup(each.value, "destination_port_range", null)
  destination_port_ranges                    = lookup(each.value, "destination_port_ranges", null)
  source_address_prefix                      = lookup(each.value, "source_address_prefix", null)
  source_address_prefixes                    = lookup(each.value, "source_address_prefixes", null)
  source_application_security_group_ids      = lookup(each.value, "source_application_security_group_ids", null)
  destination_address_prefix                 = lookup(each.value, "destination_address_prefix", null)
  destination_address_prefixes               = lookup(each.value, "destination_address_prefixes", null)
  destination_application_security_group_ids = lookup(each.value, "destination_application_security_group_ids", null)
}

resource "azurerm_subnet_network_security_group_association" "nsg" {
  count                     = local.nsg_config == null ? 0 : 1
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg[0].id
}

resource "azurerm_network_watcher_flow_log" "nfl" {
  count = var.subnet_config.flow_logs_enabled ? 1 : 0
  network_watcher_name = var.subnet_config.flow_logs.net_watcher_name
  resource_group_name  = var.subnet_config.resource_group_name
  name = lookup(local.nfl_settings, "name", "nfl-${lookup(local.nsg_config, "name", "DefaultNSGName")}")
  network_security_group_id = azurerm_network_security_group.nsg[0].id
  storage_account_id        = var.subnet_config.flow_logs.storage_id
  enabled                   = true

  retention_policy {
    enabled = true
    days    = lookup(local.nfl_settings, "retention_days", 90)
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = var.subnet_config.flow_logs.workspace_id
    workspace_region      = var.subnet_config.location
    workspace_resource_id = var.subnet_config.flow_logs.workspace_resource_id
    interval_in_minutes   = lookup(local.nfl_settings, "interval", 10)
  }
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}


output "name" {
  value = azurerm_subnet.subnet.name
}

output "id" {
  value = azurerm_subnet.subnet.id
}
