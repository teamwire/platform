template {
  source = "/etc/consul-template/templates/teamwire-voip.tmpl"
  destination = "/etc/haproxy/20-voip.cfg"
  command = "systemctl reload haproxy"
  backup = true
}
