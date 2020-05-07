#!/bin/bash -e

# SET OCSP FILE PATH
OCSPFILE="/etc/ssl/certs/server_and_intermediate_and_root.crt.ocsp"

# GENERATE OCSP FILE IF RESPONSE IS VALID
if [ -e /usr/local/bin/ocspResponder ]; then
    if [ "$#" == 0 ];then
        ocspResponder && \
                echo "set ssl ocsp-response $(/usr/bin/base64 -w 10000 $OCSPFILE)" | socat stdio unix-connect:/run/haproxy/admin.sock
    else
        ocspResponder -debug
        exit $?
    fi
fi