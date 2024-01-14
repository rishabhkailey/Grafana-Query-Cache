```bash
docker build . -t dante
docker run -it --rm dante
apt update && apt install -y curl net-tools telnet vim procps
curl -v -x socks5://user:password@localhost:1080 http://checkip.amazonaws.com
```

```bash
apt install -y stunnel4

openssl genpkey -algorithm RSA -out root-ca.key -aes256 -pass pass:
openssl req -x509 -new -nodes -key root-ca.key -sha256 -days 3650 -out root-ca.crt \
    -subj "/C=US/ST=YourState/L=YourCity/O=YourOrganization/CN=RootCA" \
    -passin pass:

openssl genpkey -algorithm RSA -out server.key -aes256 -pass pass:
openssl req -new -key server.key -out server.csr \
    -subj "/C=US/ST=YourState/L=YourCity/O=YourOrganization/CN=RootCA" \
    -passin pass:

openssl x509 -req -in server.csr -CA root-ca.crt -CAkey root-ca.key -CAcreateserial -out server.crt -days 365 \
    -passin pass:
```

```ini
[socks]
accept = 8443
connect = 127.0.0.1:1080
cert = /certs/server.crt
key = /certs/server.key
```