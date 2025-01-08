#Provider block
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.14.0"
    }
  }
}

provider "azurerm" {
  # Configuration options
  features {}
  subscription_id = "d142c4c7-733e-4ee6-9bb4-bcbe829e13c2"
}
# All Resources related to web app for staging environment 

resource "azurerm_resource_group" "staging_rg" {
  name     = "${var.name}_Rg"
  location = "East US"
}

# going to use the exisitng azure vnet 
data "azurerm_virtual_network" "vnet" {
  name                = "webapp-vnet"
  resource_group_name = "testRg"
}

resource "azurerm_subnet" "staging_subnet" {
  name                 = "${var.name}_subnet"
  resource_group_name  = azurerm_resource_group.staging_Rg.name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  #This staging_subnet will remain in azure portal even if the terraform config is destroyed
  lifecyle {
    prevent_destroy = true
  }
}

resource "azurerm_network_interface" "staging_nic_1" {
 count = var.compute_count
  name                = "${var.name}_nic_${count.index+1}"
  location            = azurerm_resource_group.staging_rg.location
  resource_group_name = azurerm_resource_group.staging_rg.name

  ip_configuration {
    name                          = "nic_config_${count.index+1}"
    subnet_id                     = azurerm_subnet.staging_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_network_security_group" "staging_nsg" {
  name                = "${var.name}_nsg"
  location            = azurerm_resource_group.staging_rg.location
  resource_group_name = azurerm_resource_group.staging_rg.name
#allowing http inbound
  security_rule {
    name                       = "http-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  #allowing http outbound 
  security_rule {
    name                       = "http-Outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "80"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}

