FROM openresty/openresty:1.21.4.3-bullseye-fat

RUN apt update && apt install -y git luarocks && \
    opm get ledgetech/lua-resty-http && \
    luarocks install luaunit && luarocks install md5

# go lang for tests
RUN wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz -O /tmp/go1.21.5.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf /tmp/go1.21.5.linux-amd64.tar.gz && \ 
    rm /tmp/go1.21.5.linux-amd64.tar.gz && \
    /usr/local/go/bin/go install -v golang.org/x/tools/cmd/goimports@latest golang.org/x/tools/gopls@latest

ENV PATH=$PATH:/usr/local/go/bin

ENV LUA_CPATH="/usr/local/openresty/lualib/?.so;/usr/local/openresty/site/lualib/?.so;/usr/local/lib/lua/5.1/?.so;"
ENV LUA_PATH="/usr/local/openresty/lualib/?.lua;/usr/local/openresty/site/lualib/?.lua;//usr/local/lib/lua/5.1?.lua;/usr/local/share/lua/5.1/?.lua;/workspaces/Grafana-Query-Cache/?.lua"