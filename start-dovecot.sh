#!/bin/bash -e
set -o pipefail

function handleSig {
    echo "Stopping dovecot..."
    dovecot stop
    echo "Dovecot stopped."
}

trap handleSig SIGINT SIGTERM SIGQUIT SIGHUP

if [ "$POSTMASTER_EMAIL" == "" ]; then
    echo "Specify the postmaster email WITH POSTMASTER_EMAIL" >&2
    exit 1;
fi

readonly CERT_FILE=/etc/dovecot/cert.pem
readonly KEY_FILE=/etc/dovecot/privkey.pem

FILE_RETRIES=0
readonly FILE_MAX_RETRIES=20
while [ ! -f "$CERT_FILE" ] && [ "$FILE_RETRIES" -lt "$FILE_MAX_RETRIES" ]; do
    echo "Certificate file [$CERT_FILE] does not exist. Waiting..."
    ls -l $(dirname "$CERT_FILE")
    sleep 5
    ((FILE_RETRIES++)) || true
done

if [ ! -f "$CERT_FILE" ]; then
    echo "Certificate file [$CERT_FILE] not found. Exiting." >&2
    exit 1
fi

FILE_RETRIES=0
readonly
while [ ! -f "$KEY_FILE" ] && [ "$FILE_RETRIES" -lt "$FILE_MAX_RETRIES" ]; do
    echo "Private key file [$KEY_FILE] does not exist. Waiting..."
    sleep 5
    ((FILE_RETRIES++)) || true
done

if [ ! -f "$KEY_FILE" ]; then
    echo "Private key file [$KEY_FILE] not found. Exiting." >&2
    exit 1
fi

echo "Starting dovecot"
dovecot -F &

cat /etc/dovecot/dovecot.conf | \
    sed -E "s/postmaster_address[= ].*\$/postmaster_address = ${POSTMASTER_EMAIL}/" \
	> /tmp/dovecot.conf

mv /tmp/dovecot.conf /etc/dovecot/dovecot.conf

cat /etc/dovecot/dovecot.conf
chown vmail:vmail /var/spool/vmail

echo "Dovecot started."

CERT_MD5=$(md5sum "$CERT_FILE" | cut -d ' ' -f1)
KEY_MD5=$(md5sum "$KEY_FILE" | cut -d ' ' -f1)

while true; do
    NEW_CERT_MD5=$(md5sum "$CERT_FILE" | cut -d ' ' -f1)
    NEW_KEY_MD5=$(md5sum "$KEY_FILE" | cut -d ' ' -f1)

    if [ "$NEW_CERT_MD5" != "$CERT_MD5" ] || [ "$NEW_KEY_MD5" != "$KEY_MD5" ]; then
	CERT_MD5="$NEW_CERT_MD5"
	KEY_MD5="$NEW_KEY_MD5"

	echo "Certificate or private key changed. Reloading."
	dovecot reload
    fi

    sleep 60 &
    wait $!
done
