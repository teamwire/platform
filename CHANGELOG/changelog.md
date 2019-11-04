## 2019-10
Teamwire on-premise platform release October 2019

### Enhancements:

- Write Ansible log to config_backup directory in management role
- Improve Redis cluster health checks for Consul
- systemd: infinite retries to restart critical services
- twctl: Allow secrets backup path to be defined
- twctl: Improve dmesg output in report file
- Warn user if using unsupported self-signed certificates

### Bugfixes:

- Add default timeout for curl commands
- Fix platform version check

### Notes:

WARNING: On cluster systems, a Nomad/backend container restart will be applied during this platform update -- so this update should be scheduled.

Please note that if you are using self-signed certificate, you will be greeted with a deprecation warning. This is due to the fact that self-signed certificates will not be supported in the future.

## 2019-09
Teamwire on-premise platform release September 2019

### Enhancements:
- plugin: Add a new ansible plugin that compares the used platform version with the current repository version.
- MOTD: Upon a SSH login, admins are now greeted with useful information such as platform/backend versions and available updates.
### Bugfixes 2019-09:
- [2019-09] Fix email delivery to root.
- [2019-09] HAProxy: Ensure the SSL Diffie-Hellman group is generated in the backend role.
- [2019-09] Docker repository signing key can fail due to unreliable connection.
- [2019-09] twctl: Fix google connection check in the connectivity feature.
### Notes:


## 2019-07
Teamwire on-premise platform release July 2019

### Enhancements:
- Introduce new changelog.
- twctl tool: The connectivity function is enhanced with an ocsp check 
- plugin: Add a new ansible plugin that compares the used platform version with the current repository version.

### Bugfixes 2019-07:
- [2019-07.1] OCSP: Ocsp check during playbook run is not enforced anymore.
- [2019-07.2] Make sure release 2019-07 is backwards compatible with older versions.
- [2019-07.2] Fix typo in the connectivity function of twctl.
- [2019-07.2] Extend the twctl report file with haproxy.log.
- [2019-07.2] On cluster systems, hosts in both the backend and frontend server groups now have full compatbility with haproxy.
- [2019-07.3] Security: Disable TCP timestamps
- [2019-07.3] Allow copy & pasting in the vim editor
- [2019-07.3] haproxy: improve client proxy support
### Notes:
