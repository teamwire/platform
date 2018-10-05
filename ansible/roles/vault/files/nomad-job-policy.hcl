# This policy allows Nomad jobs to read secrets from Vault
path "secret/*" {
  capabilities = ["read"]
}
