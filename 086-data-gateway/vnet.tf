locals {
  vnets_086 = {
    vnet_086-1 = {
      name                = "euw-vnet-086-data-gateway-01"
      location            = local.primary_location
      resource_group_name = azurerm_resource_group.rgs["rgvnet"].name
      address_space       = ["10.111.148.160/28"]
      dns_servers         = ["10.111.131.135", "10.111.131.134", "10.111.131.136", "10.111.131.133"]
      #      network_watcher_name = "nnw-gpms-prod-uksouth-001"
      # nsg_flow_log_sa     = "stnsgloggp001uksouth001"
      # nsg_flow_log_la     = {
      #   name = "lansgloggp001uksouth001"
      # }
      subnets = {
        "euw-snet-086-data-gateway-01" = {
          prefix            = "10.111.148.160/28"
          service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
          nsg = {
            name  = "euw-nsg-086-data-gateway-01"
            rules = local.euw-nsg-086-data-gateway-01-rule
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
              prefix        = "10.111.131.128/25"
              next_hop_type = "VirtualNetworkGateway"
            }
            "003defaultRouteToFirewall" = {
              prefix        = "0.0.0.0/0"
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
            "037defaultDataAnalyticsQliksense" = {
              prefix        = "10.111.135.80/28"
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


module "vnets_086" {
  source      = "../modules/vnet"
  for_each    = local.vnets_086
  vnet_config = each.value
}

locals {
  vnets_086-snetid = {
    for k, v in module.vnets_086 : k => v.subnet_ids
  }

  vnets_086-snetname = {
    for k, v in module.vnets_086 : k => v.subnet_names
  }
  #   management-snetid = tomap({
  #       for snet in data.azurerm_subnet.managementsubnets: snet.name => snet.id
  #   })
  #  local_management-snetid ={
  #   value = merge(local.vnets_085-snetid, local.management-snetid)
  #  }
}
output "subnet_ids" {
  value = local.vnets_086-snetid
}

output "subnet_names" {
  value = local.vnets_086-snetname
}

output "vnet_id" {
  value = {
    for k, v in module.vnets_086 : k => v.id
  }
}
# output "managementsubnets_subnets_ids" {
#   value = local.management-snetid
# }


resource "azurerm_virtual_network_peering" "con-to-datagw" {
  provider = azurerm.azconnectivity
  name     = "euw-pvnet-003-connectivity-01-to-086-data-gateway-01"
  #local.rgs.rgvnet01
  resource_group_name          = data.azurerm_virtual_network.convnet.resource_group_name
  virtual_network_name         = data.azurerm_virtual_network.convnet.name
  remote_virtual_network_id    = module.vnets_086["vnet_086-1"].id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
  allow_gateway_transit        = true
}


resource "azurerm_virtual_network_peering" "datagw-to-con" {

  name = "euw-pvnet-086-data-gateway-01-to-003-connectivity-01"
  #local.rgs.rgvnet01
  resource_group_name          = azurerm_resource_group.rgs["rgvnet"].name
  virtual_network_name         = local.vnets_086["vnet_086-1"].name
  remote_virtual_network_id    = data.azurerm_virtual_network.convnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = true
  allow_gateway_transit        = false
}
