#!/bin/bash -e

# GET SWISS SIGN OCSP URI
URI=$(openssl x509 -in /etc/ssl/certs/server_and_intermediate_and_root.crt -noout -text | grep -oP '(?<=OCSP - URI:).*')

# SET OCSP FILE PATH
OCSPFILE="/etc/ssl/certs/server_and_intermediate_and_root.crt.ocsp"

# GENERATE OCSP FILE
openssl ocsp -issuer /etc/ssl/certs/teamwire.intermediate.crt \
    -cert /etc/ssl/certs/teamwire.server.crt \
    -url $URI \
    -no_nonce \
    -noverify \
    -respout $OCSPFILE

# UPDATE OCSP AT HAP
[[ "$#" == 0 ]] && echo "set ssl ocsp-response $(/usr/bin/base64 -w 10000 $OCSPFILE)" | socat stdio unix-connect:/run/haproxy/admin.sock

exit 0