variable "vault-addr" {
  type        = string
  // default     = 
  description = "Vault ADDR"
}

variable "vault-namespace" {
  type        = string
  // default     = 
  description = "Vault Namespace"
}

variable "vault-token" {
  type        = string
  // default     = 
  description = "Vault token with permissions"
}

variable ".mysql-connection-url" {
  type        = string
  // default     = 
  description = "Mysql full url"
}