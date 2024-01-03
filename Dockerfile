FROM openresty/openresty:1.21.4.3-bullseye-fat


RUN mkdir -p /var/lib/nginx/cache && \
    rm /etc/nginx/conf.d/default.conf || true && \
    opm get ledgetech/lua-resty-http

COPY nginx/grafana.conf nginx/grafana_request.lua /etc/nginx/conf.d/

ENV LUA_CPATH="/usr/local/openresty/lualib/?.so;/usr/local/openresty/site/lualib/?.so;"
ENV LUA_PATH="/usr/local/openresty/lualib/?.lua;/usr/local/openresty/site/lualib/?.lua;/etc/nginx/conf.d/?.lua;"