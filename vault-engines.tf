
// vault secrets enable -path=internal kv-v2
resource "vault_mount" "internal-app-secret-engine" {
  path        = "internal"
  type        = "kv-v2"
  description = "KV2 Secrets Engine for Demo."
}

// vault kv put internal/database/config username="db-readonly-username" password="db-secret-password"
# resource "vault_generic_secret" "demo-app-secrets" {
#     path      = "${vault_mount.internal-app-secret-engine.path}/database/config"

#     depends_on = [
#       vault_mount.internal-app-secret-engine
#     ]

#   data_json = <<EOT
# {
#   "username": "db-readonly-username",
#   "password": "db-secret-password"
# }
# EOT
# }