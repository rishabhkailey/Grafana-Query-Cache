FROM openresty/openresty:1.21.4.3-bullseye-fat

RUN rm /etc/nginx/conf.d/default.conf || true && \
    opm get ledgetech/lua-resty-http

COPY grafana_request.lua /usr/local/openresty/lualib
COPY grafana.conf ssl-conf.sh /etc/nginx/templates/
COPY entrypoint.sh /opt/entrypoint.sh

ENV LUA_CPATH="/usr/local/openresty/lualib/?.so;/usr/local/openresty/site/lualib/?.so;"
ENV LUA_PATH="/usr/local/openresty/lualib/?.lua;/usr/local/openresty/site/lualib/?.lua;/etc/nginx/conf.d/?.lua;"

RUN chmod u+x /opt/entrypoint.sh
CMD ["/opt/entrypoint.sh", "start"]