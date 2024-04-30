terraform {
  required_version = ">= 1.3.0"
}

resource "azurerm_availability_set" "avail_set" {
  name                         = var.avail_set_config.name
  location                     = var.avail_set_config.location
  resource_group_name          = var.avail_set_config.resource_group_name
  tags                         = lookup(var.avail_set_config, "tags", null)
  platform_fault_domain_count  = lookup(var.avail_set_config, "failure_dom", 2)
  platform_update_domain_count = lookup(var.avail_set_config, "update_dom", 2)
  proximity_placement_group_id = lookup(var.avail_set_config, "ppg", null)

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

output "id" {
  value = azurerm_availability_set.avail_set.id
}
