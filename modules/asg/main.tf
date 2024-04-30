terraform {
  required_version = ">= 1.3.0"
}

resource "azurerm_application_security_group" "asg" {
  name                = var.asg_config.name
  location            = var.asg_config.location
  resource_group_name = var.asg_config.rg
  tags                = lookup(var.asg_config, "tags", null)

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_network_interface_application_security_group_association" "asg" {
  for_each                      = var.asg_config.nics
  network_interface_id          = each.value.id
  application_security_group_id = azurerm_application_security_group.asg.id
}
