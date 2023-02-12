FROM ubuntu:20.04

ENV container=docker
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive

RUN echo "Etc/UTC" > /etc/timezone && \
    rm -f /etc/localtime && \
    ln -s /usr/share/zoneinfo/UTC /etc/localtime && \
    apt-get -y update && \
    apt-get upgrade -y && \
    apt-get install -y \
        curl \
        gpg \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        ssl-cert \
        tini && \
    curl -L https://repo.dovecot.org/DOVECOT-REPO-GPG | gpg --import && \
    gpg --export ED409DA1 > /etc/apt/trusted.gpg.d/dovecot.gpg && \
    add-apt-repository "deb https://repo.dovecot.org/ce-2.3-latest/ubuntu/focal focal main" && \
    apt-get -y install \
        dovecot-core \
        dovecot-gssapi \
        dovecot-imapd \
        dovecot-ldap \
        dovecot-lmtpd \
        dovecot-lua \
        dovecot-lucene \
        dovecot-managesieved \
        dovecot-mysql \
        dovecot-pgsql \
        dovecot-pop3d \
        dovecot-sieve \
        dovecot-solr \
        dovecot-sqlite \
        dovecot-submissiond && \
    groupadd -g 5000 vmail && \
    useradd -u 5000 -g vmail vmail -d /var/spool/vmail && \
    passwd -l vmail && \
    rm -rf /etc/dovecot && \
    mkdir -p /var/spool/vmail /etc/dovecot && \
    chown vmail:vmail /var/spool/vmail
 
COPY start-dovecot.sh /bin/start-dovecot.sh
COPY dovecot.conf /etc/dovecot/dovecot.conf

RUN chmod 755 /bin/start-dovecot.sh

VOLUME ["/etc/dovecot", "/var/spool/vmail"]

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/start-dovecot.sh"]
