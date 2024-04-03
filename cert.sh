#!/bin/bash

# Check if a domain name is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <domain-name>"
    exit 1
fi

name="$1"

# Issue the certificate
# https://dv.acme-v02.api.pki.goog/directory
# https://dv.acme-v02.test-api.pki.goog/directory
"${HOME}/.acme.sh/acme.sh" --issue --server https://dv.acme-v02.test-api.pki.goog/directory --dns dns_bind --test -d "$name"  --keylength ec-384 --force

# Check if issuing the certificate was successful
if [ "$?" -eq 0 ]; then
    # Install the certificate
    "${HOME}/.acme.sh/acme.sh" --install-cert -d "$name" \
        --cert-file "/etc/ssl/private/${name}_ecc.cer" \
        --key-file "/etc/ssl/private/${name}_ecc.key" \
        --fullchain-file "/etc/ssl/private/${name}_fullchain_ecc.cer"
    echo "Certificate installed successfully."
else
    echo "Failed to issue the certificate."
fi
