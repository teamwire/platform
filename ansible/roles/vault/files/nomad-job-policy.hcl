# This policy allows Nomad jobs to read secrets from Vault
path "secret/database/*" { capabilities = ["read"] }
path "secret/redis/password" { capabilities = ["read"] }
path "secret/voip/*" { capabilities = ["read"] }
path "secret/keys/gcm" { capabilities = ["read"] }
