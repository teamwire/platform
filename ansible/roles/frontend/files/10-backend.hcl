template {
  source = "/etc/consul-template/templates/teamwire-backend.tmpl"
  destination = "/etc/haproxy/haproxy.cfg"
  command = "systemctl reload haproxy"
  backup = true
}
