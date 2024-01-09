FROM openresty/openresty:1.21.4.3-bullseye-fat

RUN apt update && apt install -y git && \
    opm get ledgetech/lua-resty-http

ENV LUA_CPATH="/usr/local/openresty/lualib/?.so;/usr/local/openresty/site/lualib/?.so;"
ENV LUA_PATH="/usr/local/openresty/lualib/?.lua;/usr/local/openresty/site/lualib/?.lua;"