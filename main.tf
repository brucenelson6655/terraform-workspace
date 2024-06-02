terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 2.30.0"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "region" {
  type    = string
  default = "westus"
}

data "external" "me" {
  program = ["az", "account", "show", "--query", "user"]
}

locals {
  prefix = "brn-e-adb-6598"
  rg = "brn-demo-tf-ws"
  sa = "brne6598"
  public_sub = "public-subnet"
  private_sub = "private-subnet"
  tags = {
    Environment = "Demo"
    Owner       = lookup(data.external.me.result, "name")
    RemoveAfter = "2024-11-01"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.rg}-rg"
  location = var.region
  tags     = local.tags
}

resource "azurerm_databricks_access_connector" "ac" {
  name = "${local.prefix}-ac"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  identity {
    type = "SystemAssigned"
  }

  tags = local.tags
  
}

resource "azurerm_virtual_network" "vn" {
  name = "${local.prefix}-vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
  address_space       = ["100.64.0.0/23"]
  tags = local.tags
}

resource "azurerm_subnet" "public" {
    name           = "public-subnet"
    address_prefixes = ["100.64.0.0/25"]
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vn.name
    delegation {
      name = "brn_delegation"
      service_delegation {
        name = "Microsoft.Databricks/workspaces"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action",
          "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
          "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
        ]
      }
    }
  }

resource "azurerm_subnet" "private" {
    name           = "private-subnet"
    address_prefixes = ["100.64.0.128/25"]
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vn.name
    delegation {
      name = "brn_delegation"
      service_delegation {
        name = "Microsoft.Databricks/workspaces"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action",
          "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
          "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
        ]
      }
    }
  }
  
resource "azurerm_subnet" "pe" {
    name           = "PE"
    address_prefixes = ["100.64.1.192/26"]
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vn.name
  }
  

resource "azurerm_network_security_group" "nsg" {
  name = "${local.rg}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location = azurerm_resource_group.rg.location
}

resource "azurerm_subnet_network_security_group_association" "pubnsg" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "privnsg" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_databricks_workspace" "ws" {
  name                             = "${local.prefix}-ws"
  resource_group_name              = azurerm_resource_group.rg.name
  location                         = azurerm_resource_group.rg.location
  sku                              = "premium"
  access_connector_id              = azurerm_databricks_access_connector.ac.id
  default_storage_firewall_enabled = true
  network_security_group_rules_required = "AllRules"
  public_network_access_enabled = true
  custom_parameters {
    no_public_ip             = true
    private_subnet_name      = azurerm_subnet.private.name
    public_subnet_name       = azurerm_subnet.public.name
    storage_account_name     = "dbstorage${local.sa}"
    storage_account_sku_name = "Standard_GRS"
    virtual_network_id       = azurerm_virtual_network.vn.id
    public_subnet_network_security_group_association_id = azurerm_network_security_group.nsg.id
    private_subnet_network_security_group_association_id = azurerm_network_security_group.nsg.id
  }
  managed_resource_group_name = "databricks-${local.prefix}-mrg"

  tags = local.tags
}
