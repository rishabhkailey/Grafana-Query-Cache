FROM openresty/openresty:1.25.3.1-0-bookworm-fat

RUN apt update && apt install -y luarocks=3.8.0+dfsg1-1 libyaml-dev=0.2.5-1 git wget 

# go lang for tests
RUN wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz -O /tmp/go1.21.5.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf /tmp/go1.21.5.linux-amd64.tar.gz && \ 
    rm /tmp/go1.21.5.linux-amd64.tar.gz 
    
ENV PATH=$PATH:/usr/local/go/bin

ENV LUA_CPATH=";;/usr/local/openresty/lualib/?.so;/usr/local/openresty/site/lualib/?.so;/usr/local/lib/lua/5.1/?.so;"
ENV LUA_PATH=";;/usr/local/openresty/lualib/?.lua;/usr/local/openresty/site/lualib/?.lua;//usr/local/lib/lua/5.1?.lua;/usr/local/share/lua/5.1/?.lua;/workspaces/Grafana-Query-Cache/src/?.lua;"