FROM debian:bookworm-20240110
RUN apt update && apt install -y dante-server
COPY sockd.conf /etc/sockd.conf
COPY entrypoint.sh /opt/entrypoint.sh
ENV DANTE_USER=user
ENV DANTE_PASSWORD=password
CMD ["/bin/bash", "/opt/entrypoint.sh"]
