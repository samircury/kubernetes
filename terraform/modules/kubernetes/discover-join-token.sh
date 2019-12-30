#!/bin/bash

# Parsing master from TF External Source input
eval "$(jq -r '@sh "export MASTER=\(.master) "')"

# Just waits until there's a token to be grabbed from the log
ssh $MASTER -o "StrictHostKeyChecking=no" \
        'while [ ! -e /var/log/ansible-bootstrap.log -o -z "$(grep \\-\\-token /var/log/ansible-bootstrap.log)" ]; do  sleep 2; done'


# TODO: Switch this to a Token Generator. We'd be counting only on ssh access to
# the master from the TF deployment host.
JOIN_DATA=$(ssh $MASTER "sudo tail -n200 /var/log/ansible-bootstrap.log | grep discovery-token " | perl\
        -nle 'm/.*--token (.{10,30}).*--discovery-token-ca-cert-hash (sha256:.{20,80})\".*/ ; print "$1 - $2"')

JOIN_KEY=$(echo $JOIN_DATA | awk -F'-' '{print $1}') # split()[0]
CA_CERT=$(echo $JOIN_DATA | awk -F'-' '{print $2}') # split()[1]


jq -n \
    --arg join_key "$JOIN_KEY" \
    --arg ca_cert "$CA_CERT" \
    '{"join_key":$join_key,"ca_cert":$ca_cert}'