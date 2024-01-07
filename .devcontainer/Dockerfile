FROM openresty/openresty:1.21.4.3-bullseye-fat

RUN apt update && apt install -y git wget && \
    opm get ledgetech/lua-resty-http

# go lang for tests
RUN wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz -O /tmp/go1.21.5.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf /tmp/go1.21.5.linux-amd64.tar.gz && \ 
    export PATH=$PATH:/usr/local/go/bin && \
    rm /tmp/go1.21.5.linux-amd64.tar.gz

ENV LUA_CPATH="/usr/local/openresty/lualib/?.so;/usr/local/openresty/site/lualib/?.so;"
ENV LUA_PATH="/usr/local/openresty/lualib/?.lua;/usr/local/openresty/site/lualib/?.lua;"

