locals {
  vnets_087 = {
    vnet_087-1 = {
      name                = "euw-vnet-087-files-pit-01"
      location            = local.primary_location
      resource_group_name = azurerm_resource_group.rgs["rgvnet"].name
      # address_space       = ["10.111.148.144/28"]
      # dns_servers         = ["10.111.131.135", "10.111.131.134", "10.111.131.136"]
      subnets = {
        "euw-snet-087-files-pit-01" = {
          # prefix            = "10.111.148.144/28"
          service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
          nsg = {
            name  = "euw-nsg-087-files-pit-01"
            rules = local.euw-nsg-087-files-pit-01-rule
          }
          route_table = "euw-rtable-01"
        }
      }
      route_tables = {
        "euw-rtable-01" = {
          routes = {
            "001defaultManagement" = {
              prefix        = "10.111.131.0/26"
              next_hop_type = "VirtualNetworkGateway"
            }
            "002defaultIdentity" = {
              prefix        = "10.181.0.0/24"
              next_hop_type = "VirtualNetworkGateway"
            }
            "003defaultRouteToFirewall" = {
              prefix        = "10.181.57.128/25"
              next_hop_type = "VirtualAppliance"
              next_hop_ip   = "10.111.130.196"
            }
            "023defaultSnowSwInventory" = {
              prefix        = "10.111.134.128/26"
              next_hop_type = "VirtualNetworkGateway"
            }
            "032defaultMailDomainService" = {
              prefix        = "10.111.135.128/28"
              next_hop_type = "VirtualNetworkGateway"
            }
            "035default-PRTGMonitoring" = {
              prefix        = "10.111.135.176/28"
              next_hop_type = "VirtualNetworkGateway"
            }
            "041defaultQradar-gateway" = {
              prefix        = "10.111.136.144/28"
              next_hop_type = "VirtualNetworkGateway"
            }
            "044defaultFTP" = {
              prefix        = "10.111.136.224/28"
              next_hop_type = "VirtualNetworkGateway"
            }
            "Routing-SAP-Fujitsu-01" = {
              prefix        = "10.111.144.0/24"
              next_hop_type = "VirtualNetworkGateway"
            }
            "Routing-SAP-Fujitsu-02" = {
              prefix        = "10.111.145.0/24"
              next_hop_type = "VirtualNetworkGateway"
            }
          }
        }

      }
    }
  }
}


module "vnets_087" {
  source      = "../modules/vnet"
  for_each    = local.vnets_087
  vnet_config = each.value
}

locals {
  vnets_087-snetid = {
    for k, v in module.vnets_087 : k => v.subnet_ids
  }

  vnets_087-snetname = {
    for k, v in module.vnets_087 : k => v.subnet_names
  }
}
output "subnet_ids" {
  value = local.vnets_087-snetid
}

output "subnet_names" {
  value = local.vnets_087-snetname
}

output "vnet_id" {
  value = {
    for k, v in module.vnets_087 : k => v.id
  }
}

resource "azurerm_virtual_network_peering" "con-to-pit" {
  provider = azurerm.azconnectivity
  name     = "euw-pvnet-003-connectivity-01-to-087-files-pit-01"
  resource_group_name          = data.azurerm_virtual_network.convnet.resource_group_name
  virtual_network_name         = data.azurerm_virtual_network.convnet.name
  remote_virtual_network_id    = module.vnets_087["vnet_087-1"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
  allow_gateway_transit        = true
}
resource "azurerm_virtual_network_peering" "pit-to-con" {

  name = "087-files-pit-01-to-euw-pvnet-003-connectivity-01"
  resource_group_name          = azurerm_resource_group.rgs["rgvnet"].name
  virtual_network_name         = local.vnets_087["vnet_087-1"].name
  remote_virtual_network_id    = data.azurerm_virtual_network.convnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true
  allow_gateway_transit        = false
}
