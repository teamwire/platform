namespace "*" {
  policy = "read"
}

resource "job" {
  capabilities = ["submit", "read", "update", "list", "deregister"]
}
