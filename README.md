Dovecot IMAP server in a Docker container.

Dovecot handles email clients, but does not handle receiving email (Postfix can be used for this).

## Required variables
- POSTMASTER_EMAIL: Email address of the postmaster (server-related email)

## Ports
- 993: IMAP
- 24: LMTP (for communication with SMTP servers like Postfix).

## Adding Users
This Docker image uses passwd-style authentication.

To add users, open a shell in the dovecot container and run:
```console
doveadm pw -s SHA512-CRYPT
```
This will generate a hash for the password you enter.

In dovecot-passwd (create if needed), enter the username followed by a colon, then copy and paste the output from the above `doveadm pw` command.

### Example of adding a user

```console
rick@u1:~/docker-compose/mail-server$ docker-compose exec dovecot doveadm pw -s SHA512-CRYPT
Enter new password:
Retype new password:
{SHA512-CRYPT}$6$rK.UUL/EpQi53VOL$sjMQ0nZbLujLCkZEOkUHCyNl644OviavtWdcsuZ5CyHNQoCehl/gKyl/eCLM6LGbbWJjpNEMfa5mFfwlvmHkX1
```

Then the output was added to dovecot-passwd:
```
user@example.com:{SHA512-CRYPT}$6$rK.UUL/EpQi53VOL$sjMQ0nZbLujLCkZEOkUHCyNl644OviavtWdcsuZ5CyHNQoCehl/gKyl/eCLM6LGbbWJjpNEMfa5mFfwlvmHkX1
```


## Example

This example assumes dovecot-passwd is in the current directory, and that Let's Encrypt is being used for TLS certificates.

```console
docker run \
    --mount type=bind,source=$(pwd)/dovecot-passwd,destination=/etc/dovecot/passwd,readonly=true \
    --mount type=bind,source=/etc/letsencrypt/live/your-email-servers-hostname.com/privkey.pem,destination=/etc/dovecot/privkey.pem,readonly=true \
    --mount type=bind,source=/etc/letsencrypt/live/your-email-servers-hostname.com/fullchain.pem,destination=/etc/dovecot/cert.pem,readonly=true \
    -e RECEIVE_FOR_DOMAINS="domain-to-receive-email-for.com another-domain-to-receive-email-for.com" \
    -e EMAIL_HOST=your-email-servers-hostname.com \
    --rm \
    -p 993:993 \
    kernrj/dovecot
```

## docker-compose example

This example also adds postfix and certbot.

```yml
version: '2'
services:
    postfix:
        image: kernrj/postfix
        restart: always
        volumes:
            - type: bind
              source: /etc/letsencrypt/live/mx1.your-server.com/fullchain.pem
              target: /certs/fullchain.pem
              read_only: true
            - type: bind
              source: /etc/letsencrypt/live/mx1.your-server.com/privkey.pem
              target: /certs/privkey.pem
              read_only: true
        environment:
            - EMAIL_HOST=mx1.your-server.com
            - RECEIVE_FOR_DOMAINS="domain1.com domain2.com"
            - CERT_FILE=/certs/fullchain.pem
            - KEY_FILE=/certs/privkey.pem
        ports:
            - 25:25

    dovecot:
        image: kernrj/dovecot
        restart: always
        volumes:
            - type: bind
              source: ./dovecot-passwd
              target: /etc/dovecot/passwd
              read_only: true
            - type: bind
              source: /etc/letsencrypt/live/mx1.your-server.com/fullchain.pem
              target: /etc/dovecot/cert.pem
              read_only: true
            - type: bind
              source: /etc/letsencrypt/live/mx1.your-server.com/privkey.pem
              target: /etc/dovecot/privkey.pem
              read_only: true
            - "./mail:/var/spool/vmail"
        environment:
            - POSTMASTER_EMAIL=your_email@example.com
        ports:
            - 993:993

    certbot: # creates or renews a certificate for the email server once every 30 days
        image: kernrj/certbot
        restart: always
        init: true
        volumes:
            - type: bind
              source: /etc/letsencrypt
              target: /etc/letsencrypt
        environment:
            - CERT_DOMAIN=mx1.yourserver.com
            - CERT_EMAIL=your_email@example.com
            - AGREE_TOS=yes # Specifying "yes" means you agree to the terms of service in the certbot application in the container being launched. This is equivalent to `certbot --agree-tos`.
        ports:
            - 80:80
```
