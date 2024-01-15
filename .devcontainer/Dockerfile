FROM openresty/openresty:1.21.4.3-bullseye-fat

RUN apt update && apt install -y git luarocks && \
    opm get ledgetech/lua-resty-http && \
    luarocks install luaunit && luarocks install md5

ENV LUA_CPATH="/usr/local/openresty/lualib/?.so;/usr/local/openresty/site/lualib/?.so;/usr/local/lib/lua/5.1/?.so;"
ENV LUA_PATH="/usr/local/openresty/lualib/?.lua;/usr/local/openresty/site/lualib/?.lua;//usr/local/lib/lua/5.1?.lua;/usr/local/share/lua/5.1/?.lua;/workspaces/Grafana-Query-Cache/?.lua"