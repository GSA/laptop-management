#!/bin/sh
#
# osquery setup script for https://github.com/zentralopensource/zentral
# on debian/ubuntu systems
#

set -e

get_machine_id () {
  if [ -e /etc/monitoringclient/client_settings.conf ]; then
    MACHINE_ID=$(python -c 'import json;print json.load(open("/etc/monitoringclient/client_settings.conf", "r"))["WatchmanID"]')
  fi
  if [ -x /usr/sbin/dmidecode ]; then
    MACHINE_ID=$(dmidecode -s system-uuid)
  fi
  if [ ! $MACHINE_ID ]; then
    MACHINE_ID=$(cat /var/lib/dbus/machine-id)
  fi
}

restart_osqueryd () {
  if [ -x /bin/systemctl ]; then
    sudo systemctl restart osqueryd
  else
    sudo /etc/init.d/osqueryd restart
  fi
}

restart_rsyslog () {
  if [ -x /bin/systemctl ]; then
    sudo systemctl restart rsyslog
  else
    sudo service rsyslog restart
  fi
}

# add apt https transport if missing
sudo apt-get install -y apt-transport-https

# add osquery repository key
sudo apt-key adv --keyserver keyserver.ubuntu.com \
                 --recv-keys 1484120AC4E9F8A1A577AEEE97A80C63C9D8B80B

# add/replace osquery repository
sudo /bin/sed -i '/^deb.*osquery.*$/d' /etc/apt/sources.list
DISTRO=$(lsb_release -c|cut -d ':' -f2| tr  -d "\t")
echo "deb [arch=amd64] https://osquery-packages.s3.amazonaws.com/xenial xenial main" | sudo /usr/bin/tee -a /etc/apt/sources.list

# update available package list
sudo apt-get update

# install osquery
sudo apt-get install -y osquery

# rsyslogd pipe for osquery
sudo cat << RSYSLOGD > /etc/rsyslog.d/60-osquery.conf
template(
  name="OsqueryCsvFormat"
  type="string"
  string="%timestamp:::date-rfc3339,csv%,%hostname:::csv%,%syslogseverity:::csv%,%syslogfacility-text:::csv%,%syslogtag:::csv%,%msg:::csv%\n"
)
*.* action(type="ompipe" Pipe="/var/osquery/syslog_pipe" template="OsqueryCsvFormat")
RSYSLOGD

restart_rsyslog
restart_osqueryd

# create zentral config dir
sudo mkdir -p /etc/zentral/osquery

# server certs
sudo cat << TLS_SERVER_CERT > /etc/zentral/tls_server_certs.crt
-----BEGIN CERTIFICATE-----
MIIDljCCAn4CCQDwas1VQZ98fzANBgkqhkiG9w0BAQsFADCBjzELMAkGA1UEBhMC
REUxEDAOBgNVBAgMB0hhbWJ1cmcxEDAOBgNVBAcMB0hhbWJ1cmcxEjAQBgNVBAoM
CUFwZmVsd2VyazETMBEGA1UECwwKWmVudHJhbCBDQTETMBEGA1UEAwwKWmVudHJh
bCBDQTEeMBwGCSqGSIb3DQEJARYPaW5mb0B6ZW50cmFsLmlvMB4XDTE1MTAxODEz
NTEyOVoXDTE4MDgwNzEzNTEyOVowgYkxCzAJBgNVBAYTAkRFMRAwDgYDVQQIDAdI
YW1idXJnMRAwDgYDVQQHDAdIYW1idXJnMRIwEAYDVQQKDAlBcGZlbHdlcmsxEDAO
BgNVBAsMB1plbnRyYWwxEDAOBgNVBAMMB3plbnRyYWwxHjAcBgkqhkiG9w0BCQEW
D2luZm9AemVudHJhbC5pbzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
AMawXnbjQT9BV5yMJ/Fblcz+8iynRnDKT5PK/KQ4ZIpsA1eQCpLKH/Wl53swcbH5
FN+Bc4GFYe7FB8wRpRXLzC7MNdnGug5HjRjZFRV/hVgKrA3Za6OiPpoCTWlVbglI
+bSxS4JezGnJoPVyILXsl17/ITQhvLiE09JCdk6NlkLsKgX1oqiOkR15txcr2R/g
ilLnKuxD4pkeojV/a8FLlwHhiRE/nqm50Qv11KvoB5meeGDEFgn0fYUMGkHYU15P
4KNOgCkY8blBIHYKVKwH7DcnJxT7b9m2ThQQmmKX15Jb0QLMnsLkgBoGULIBGKql
Bh9aJVcLBF+nHUpO62GrNUcCAwEAATANBgkqhkiG9w0BAQsFAAOCAQEAfZFayDEQ
U4JhIuDc08Jh9JBmm1wzkOx1buzDiiyru+ANEvBXp8A96xeamIjFP6STaKTrr/2S
2IvVmf8qCCDuWvpkj09hhzpPs1ml07i46X3gJiksbstZCAU+HoxaQlFJcaRS7B2Y
rnpSyRHPGy5tsSkHEY+tGetFkPA3qgdFkwD7LF0vNP2J8QDfIkvqlkIzQ96wxw+J
3CkkpmgwSW5WEv9YF01hp+P8at+ILmA82JxYsx8lpdK9u+U/yY7jD0ETsB71mU4d
XSVK4+BPL2bCmTgUJC/1cYKks+hujd5yDzXPuJeMRlJ5D5rEXJHRFlc+FJmgnI0E
P3JJxBwV85duyw==
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIID8zCCAtugAwIBAgIJAJhCj+gxLj2qMA0GCSqGSIb3DQEBCwUAMIGPMQswCQYD
VQQGEwJERTEQMA4GA1UECAwHSGFtYnVyZzEQMA4GA1UEBwwHSGFtYnVyZzESMBAG
A1UECgwJQXBmZWx3ZXJrMRMwEQYDVQQLDApaZW50cmFsIENBMRMwEQYDVQQDDApa
ZW50cmFsIENBMR4wHAYJKoZIhvcNAQkBFg9pbmZvQHplbnRyYWwuaW8wHhcNMTUx
MDE4MTM1MDA0WhcNMTgwODA3MTM1MDA0WjCBjzELMAkGA1UEBhMCREUxEDAOBgNV
BAgMB0hhbWJ1cmcxEDAOBgNVBAcMB0hhbWJ1cmcxEjAQBgNVBAoMCUFwZmVsd2Vy
azETMBEGA1UECwwKWmVudHJhbCBDQTETMBEGA1UEAwwKWmVudHJhbCBDQTEeMBwG
CSqGSIb3DQEJARYPaW5mb0B6ZW50cmFsLmlvMIIBIjANBgkqhkiG9w0BAQEFAAOC
AQ8AMIIBCgKCAQEAoQu0NQlc2ECqrgG1ai3WnbquOj6LVP/tPDnD/XvpxScuovj4
YSd5l1SnidND1QuSy/7qSvnRmf8Y8w4zvxqbDFB9EMyX3oh9soo6k7147Y2vdtLy
fsYUWljf6Hcn0zvv0KMnS9N0Sga2P2vwkdFxfoWAFzJKmqQPwepzEAEvnMNebvp8
fiVzB1UddfCzjtHw8oM1oD4duW3HmdujReGJHPebo89IHl8MyclaLpoLxnFeU0rp
z+/e66JMsqykOfd2Ikqhk1H8OXiQUjpxLQe3RdfqwV8ay970Eo09BaGxM08/BPxI
/BoEqe4Rmcwm/PJTw69gRT0sT4YKKxydiqn1XQIDAQABo1AwTjAdBgNVHQ4EFgQU
whrYCuzlEamPvVI2gXfBu5amRsMwHwYDVR0jBBgwFoAUwhrYCuzlEamPvVI2gXfB
u5amRsMwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAESj0MAPIw+n9
ZShfaFwrT43rwpi/j66CYB2tKRgDMfF5sW2hnGpQX90ph4CRvcFhExt0SExhLnsS
U2XSXl4VBnlWj9RmUv5lCIvxx3P21z3Y+w6TiKmCh9Wye+k3sMCn7+k1bpcuKEVC
ttucT6ATNkfsAD2ws34p5Ob6TqcRypKXEQz26RJtRGFda8eH0Az5ZsgKXb/RRP6b
cN7iVjfNIZNdK0mmYS/qNNkFwEKFqKEuCplL5OvmPfUdsk1O8JL+ToxbHKIepGng
VQXBNkNdLbeb76NbUOslm/B7FLZbHsdpV2vXQT7kbT8u5rxDNIBV+G7qRGKrShgv
gva5WBLbSQ==
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIID8zCCAtugAwIBAgIJAJhCj+gxLj2qMA0GCSqGSIb3DQEBCwUAMIGPMQswCQYD
VQQGEwJERTEQMA4GA1UECAwHSGFtYnVyZzEQMA4GA1UEBwwHSGFtYnVyZzESMBAG
A1UECgwJQXBmZWx3ZXJrMRMwEQYDVQQLDApaZW50cmFsIENBMRMwEQYDVQQDDApa
ZW50cmFsIENBMR4wHAYJKoZIhvcNAQkBFg9pbmZvQHplbnRyYWwuaW8wHhcNMTUx
MDE4MTM1MDA0WhcNMTgwODA3MTM1MDA0WjCBjzELMAkGA1UEBhMCREUxEDAOBgNV
BAgMB0hhbWJ1cmcxEDAOBgNVBAcMB0hhbWJ1cmcxEjAQBgNVBAoMCUFwZmVsd2Vy
azETMBEGA1UECwwKWmVudHJhbCBDQTETMBEGA1UEAwwKWmVudHJhbCBDQTEeMBwG
CSqGSIb3DQEJARYPaW5mb0B6ZW50cmFsLmlvMIIBIjANBgkqhkiG9w0BAQEFAAOC
AQ8AMIIBCgKCAQEAoQu0NQlc2ECqrgG1ai3WnbquOj6LVP/tPDnD/XvpxScuovj4
YSd5l1SnidND1QuSy/7qSvnRmf8Y8w4zvxqbDFB9EMyX3oh9soo6k7147Y2vdtLy
fsYUWljf6Hcn0zvv0KMnS9N0Sga2P2vwkdFxfoWAFzJKmqQPwepzEAEvnMNebvp8
fiVzB1UddfCzjtHw8oM1oD4duW3HmdujReGJHPebo89IHl8MyclaLpoLxnFeU0rp
z+/e66JMsqykOfd2Ikqhk1H8OXiQUjpxLQe3RdfqwV8ay970Eo09BaGxM08/BPxI
/BoEqe4Rmcwm/PJTw69gRT0sT4YKKxydiqn1XQIDAQABo1AwTjAdBgNVHQ4EFgQU
whrYCuzlEamPvVI2gXfBu5amRsMwHwYDVR0jBBgwFoAUwhrYCuzlEamPvVI2gXfB
u5amRsMwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAESj0MAPIw+n9
ZShfaFwrT43rwpi/j66CYB2tKRgDMfF5sW2hnGpQX90ph4CRvcFhExt0SExhLnsS
U2XSXl4VBnlWj9RmUv5lCIvxx3P21z3Y+w6TiKmCh9Wye+k3sMCn7+k1bpcuKEVC
ttucT6ATNkfsAD2ws34p5Ob6TqcRypKXEQz26RJtRGFda8eH0Az5ZsgKXb/RRP6b
cN7iVjfNIZNdK0mmYS/qNNkFwEKFqKEuCplL5OvmPfUdsk1O8JL+ToxbHKIepGng
VQXBNkNdLbeb76NbUOslm/B7FLZbHsdpV2vXQT7kbT8u5rxDNIBV+G7qRGKrShgv
gva5WBLbSQ==
-----END CERTIFICATE-----

TLS_SERVER_CERT

# enroll secret
get_machine_id
sudo cat << ENROLL_SECRET > /etc/zentral/osquery/enroll_secret.txt
eyJtb2R1bGUiOiJ6ZW50cmFsLmNvbnRyaWIub3NxdWVyeSJ9:1ctQ4B:4vA089CiZ4qPjIaL-Qpp8UkFsCs\$SERIAL\$$MACHINE_ID
ENROLL_SECRET

# config info
sudo cat << CONFIG_INFO > /etc/zentral/info.cfg
[server]
base_url: https://0.0.0.0
CONFIG_INFO

# TODO log rotation

# reset db dir
sudo rm -rf /var/osquery/zentral
sudo mkdir -p /var/osquery/zentral

# flags file
sudo cat << OSQUERY_FLAGS > /etc/osquery/osquery.flags
--tls_hostname=0.0.0.0
--tls_server_certs=/etc/zentral/tls_server_certs.crt
--database_path=/var/osquery/zentral
--enroll_tls_endpoint=/osquery/enroll
--enroll_secret_path=/etc/zentral/osquery/enroll_secret.txt
--config_plugin=tls
--config_tls_endpoint=/osquery/config
--config_tls_refresh=120
--logger_plugin=tls
--logger_tls_endpoint=/osquery/log
--logger_tls_period=60
--disable_distributed=false
--distributed_plugin=tls
--distributed_tls_read_endpoint=/osquery/distributed/read
--distributed_tls_write_endpoint=/osquery/distributed/write
--distributed_interval=60
--disable_audit=false
--audit_allow_config=true
--audit_persist=true
OSQUERY_FLAGS

restart_osqueryd
