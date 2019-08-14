template {
  source = "/etc/consul-template/templates/teamwire-backend.tmpl"
  destination = "/etc/haproxy/03-frontend.cfg"
  command = "systemctl reload haproxy"
  backup = true
}
