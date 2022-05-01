
resource "vault_policy" "example" {
  name = "dev-team"

  policy = <<EOT
    path "secret/my_app" {
      capabilities = ["update"]
    }
  EOT
}

resource "vault_policy" "app-1-policy" {
  name = "app-1-policy"

  policy = <<EOT
path "/secret/data/app-1/*" {
  capabilities = ["read"]
}
path "/internal/data/database/config" {
  capabilities = ["read"]
}
  EOT
}
resource "vault_policy" "app-2-policy" {
  name = "app-2-policy"

  policy = <<EOT
path "/secret/data/app-2/*" {
  capabilities = ["read"]
}
path "/internal/data/database/config" {
  capabilities = ["read"]
}
  EOT
}


resource "vault_policy" "app-3-policy" {
  name   = "app-3-policy"
  policy = <<EOT
path "/secret/data/app-3/*" {
  capabilities = ["read"]
}
path "/internal/data/database/config" {
  capabilities = ["read"]
}
  EOT
}

resource "vault_policy" "app-4-policy" {
  name   = "app-4-policy"
  policy = <<EOT
path "/secret/data/app-4/*" {
  capabilities = ["read"]
}
path "/internal/data/database/config" {
  capabilities = ["read"]
}
  EOT
}