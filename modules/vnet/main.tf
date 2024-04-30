terraform {
  required_version = ">= 1.3.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "> 3"
    }
  }
}


resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_config.name
  resource_group_name = var.vnet_config.resource_group_name
  location            = var.vnet_config.location
  address_space       = var.vnet_config.address_space
  tags                = lookup(var.vnet_config, "tags", null)
  dns_servers         = lookup(var.vnet_config, "dns_servers", null)

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_network_watcher" "nw" {
  count               = lookup(var.vnet_config, "network_watcher_name", "false") == "false" ? 0 : 1
  name                = var.vnet_config.network_watcher_name
  location            = var.vnet_config.location
  resource_group_name = var.vnet_config.resource_group_name
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_storage_account" "nwsa" {
  count                    = lookup(var.vnet_config, "nsg_flow_log_sa", "false") == "false" ? 0 : 1
  name                     = var.vnet_config.nsg_flow_log_sa
  resource_group_name      = var.vnet_config.resource_group_name
  location                 = var.vnet_config.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_log_analytics_workspace" "la" {
  count               = lookup(var.vnet_config, "nsg_flow_log_la", "false") == "false" ? 0 : 1
  name                = var.vnet_config.nsg_flow_log_la.name
  location            = var.vnet_config.location
  resource_group_name = var.vnet_config.resource_group_name
  retention_in_days   = lookup(var.vnet_config.nsg_flow_log_la, "retention", 90)
  daily_quota_gb      = lookup(var.vnet_config.nsg_flow_log_la, "quota", 10)
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

locals {
  flow_logs_enabled = lookup(var.vnet_config, "nsg_flow_log_la", "false") == "false" ? false : true
  flow_logs = {
    net_watcher_name      = try(azurerm_network_watcher.nw[0].name, null)
    storage_id            = try(azurerm_storage_account.nwsa[0].id, null)
    workspace_id          = try(azurerm_log_analytics_workspace.la[0].workspace_id, null)
    workspace_resource_id = try(azurerm_log_analytics_workspace.la[0].id, null)
  }
  subnet_config = {
    for k, v in var.vnet_config.subnets : k => merge({
      resource_group_name  = var.vnet_config.resource_group_name
      virtual_network_name = azurerm_virtual_network.vnet.name
      location             = var.vnet_config.location
      name                 = k
      flow_logs_enabled    = local.flow_logs_enabled
      flow_logs            = local.flow_logs
      tags                 = lookup(var.vnet_config, "tags", null)
    }, v)
  }

  route_table_config = {
    for k, v in lookup(var.vnet_config, "route_tables", {}) : k => merge({
      resource_group_name = var.vnet_config.resource_group_name
      location            = var.vnet_config.location
      name                = k
      tags                = lookup(var.vnet_config, "tags", null)
    }, v)
  }
}


module "subnets" {
  source        = "../subnet"
  for_each      = local.subnet_config
  subnet_config = each.value
}

module "routetables" {
  source             = "../routetable"
  for_each           = local.route_table_config
  route_table_config = each.value
}

resource "azurerm_subnet_route_table_association" "route" {
  for_each = {
    for k, v in local.subnet_config :
    k => v
    if lookup(v, "route_table", null) != null
  }
  subnet_id      = module.subnets[each.key].id
  route_table_id = module.routetables["${each.value.route_table}"].id
}

output "subnet_ids" {
  value = {
    for k, v in module.subnets : k => v.id
  }
}

output "subnet_names" {
  value = {
    for k, v in module.subnets : k=> v.name
  }
}

output "id" {
  value = azurerm_virtual_network.vnet.id
}
