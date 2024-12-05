consul {
  retry {
    # This specifies the number of attempts to make before giving up. Each
    # attempt adds the exponential backoff sleep time. Setting this to
    # zero will implement an unlimited number of retries.
    attempts = 10

    # This is the base amount of time to sleep between retry attempts. Each
    # retry sleeps for an exponent of 2 longer than this base. For 5 retries,
    # the sleep times would be: 250ms, 500ms, 1s, 2s, then 4s.
    backoff = "10s"

    # This is the maximum amount of time to sleep between retry attempts.
    # When max_backoff is set to zero, there is no upper limit to the
    # exponential sleep between retry attempts.
    # If max_backoff is set to 10s and backoff is set to 1s, sleep times
    # would be: 1s, 2s, 4s, 8s, 10s, 10s, ...
    max_backoff = "1m"
  }

# This is the address of the Consul agent.
  address = "127.0.0.1:8500"
}
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

vault {
  address = "https://vault.service.consul:8200"
  token = ""
  renew_token = false
}
