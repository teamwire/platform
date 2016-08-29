# This is the address of the Consul agent.
consul = "consul.service.consul:8500"

# This is the amount of time to wait before retrying a connection to Consul.
retry = "10s"

# This is the maximum interval to allow "stale" data.
max_stale = "10m"

# This is the quiescence timers; it defines the minimum and maximum amount of
# time to wait for the cluster to reach a consistent state before rendering a
# template.
wait = "5s:10s"

# This is the path to store a PID file which will contain the process ID of the
# Consul Template process.
pid_file = "/var/run/consul-template.pid"

log_level = "info"

syslog {
  enabled = true
  facility = "LOCAL5"
}

template {
  source = "/etc/consul-template/templates/teamwire-backend.tmpl"
  destination = "/etc/nginx/sites-available/teamwire-backend"
  command = "service nginx reload"
  backup = true
}
