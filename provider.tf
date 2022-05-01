// credentials "app.terraform.io" {
//   token = "xxxxxx.atlasv1.zzzzzzzzzzzzz"
// }

terraform {
  cloud {
    organization = "mag"

    workspaces {
      name = "onboarding"
    }
  }

  
  required_providers {
    vault = {
      version = "3.1.1"
    }
    restapi = {
      source = "fmontezuma/restapi"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}

provider "vault" {
  address = var.vault-addr // var.vault-url
  skip_tls_verify = true
  token = var.vault-token // var.token
}