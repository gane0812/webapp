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

module "webapp_staging" {
    source="./staging"
}