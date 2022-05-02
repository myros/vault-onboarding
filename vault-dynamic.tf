// # 
// # ENABLE DATABASE ENGINE
// # ============================================
// resource "vault_mount" "db" {
//   path = "database"
//   type = "database"
// }

// # 
// # STATIC
// # ============================================
// // vault write database/config/mysql-wp-db \
// //     plugin_name=mysql-database-plugin \
// //     allowed_roles="*" \
// //     connection_url="{{username}}:{{password}}@tcp(ip_address:3306)/" \
// //     username="v1" \
// //     password="password"
// resource "vault_database_secret_backend_connection" "mysql" {
//   backend       = vault_mount.db.path
//   name          = "mysql"
//   allowed_roles = ["*"]

//   mysql {
//     connection_url = var.mysql-connection-url
//   }
// }

// //  vault write database/static-roles/mysql-db-wp \
// //     db_name=mysql-wp-db \
// //     rotation_statements="SET PASSWORD = PASSWORD('{{password}}');" \
// //     username="v1" \
// //     rotation_period=300
// resource "vault_database_secret_backend_static_role" "static_role" {
//   backend             = vault_mount.db.path
//   name                = "app-1"
//   db_name             = vault_database_secret_backend_connection.mysql.name
//   username            = "vault-static"
//   rotation_period     = "3600"
//   rotation_statements = ["SET PASSWORD = PASSWORD('{{password}}');"]
// }

// # 
// # DYNAMIC 
// # ============================================

// // resource "vault_database_secret_backend_connection" "mysql" {
// //   backend       = vault_mount.db.path
// //   name          = "mysql"
// //   allowed_roles = ["mysql-role"]

// //   mysql {
// //     // password = "123123"
// //     // username = "vault"
// //     connection_url = "vault:123123@tcp(209.126.6.141:3306)/"
// //   }
// // }

// resource "vault_database_secret_backend_role" "mysql-role" {
//   backend             = vault_mount.db.path
//   name                = "mysql-app-1"
//   db_name             = vault_database_secret_backend_connection.mysql.name
//   creation_statements = ["CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT ALL PRIVILEGES ON wp.* TO '{{name}}'@'%';"]
// }


// resource "vault_policy" "db" {
//   name = "db-app-policy"

//   policy = <<EOT
//     path "database/creds/*" {
//       capabilities = [ "read" ]
//     }

//     path "database/static-creds/*" {
//       capabilities = [ "read" ]
//     }
//   EOT
// }

// // resource "vault_kubernetes_auth_backend_role" "role-db" {
// //   backend                = vault_auth_backend.kubernetes.path
// //   role_name                        = "db-role"
// //   bound_service_account_names      = ["default"]
// //   bound_service_account_namespaces = ["vault-injector", "banzai-webhook"]
// //   token_ttl                        = 3600
// //   token_policies                   = ["db-app-policy"]
// //   # audience                         = "vault"
// // }