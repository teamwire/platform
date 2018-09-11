template {
  source = "/etc/consul-template/templates/teamwire-backend.tmpl"
  destination = "/etc/nginx/sites-available/teamwire-backend"
  command = "service nginx reload"
  backup = true
}
