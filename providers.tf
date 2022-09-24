terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    aviatrix = {
      source = "AviatrixSystems/aviatrix"
    }
    null = {
      source = "hashicorp/null"
    }
  }
}