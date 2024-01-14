# must be running with root user
useradd -r -s /bin/false $DANTE_USER || true
(printf "${DANTE_PASSWORD}\n${DANTE_PASSWORD}" | passwd $DANTE_USER) || true

/usr/sbin/danted -f /etc/sockd.conf