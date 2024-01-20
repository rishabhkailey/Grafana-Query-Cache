FROM openresty/openresty:1.25.3.1-0-bookworm-fat

RUN rm /etc/nginx/conf.d/default.conf || true && \
    apt update && apt install -y luarocks=3.8.0+dfsg1-1 gettext-base=0.21-12 && \
    opm get ledgetech/lua-resty-http=0.17.1 && \
    luarocks install md5 1.3-1 && \
    apt-get remove -y --purge luarocks && apt autoremove -y

COPY grafana_request.lua /usr/local/openresty/lualib
COPY grafana.conf ssl-conf.sh /etc/nginx/templates/
COPY entrypoint.sh /opt/entrypoint.sh

ENV LUA_CPATH="/usr/local/openresty/lualib/?.so;/usr/local/openresty/site/lualib/?.so;/usr/local/lib/lua/5.1/?.so;"
ENV LUA_PATH="/usr/local/openresty/lualib/?.lua;/usr/local/openresty/site/lualib/?.lua;//usr/local/lib/lua/5.1?.lua;/usr/local/share/lua/5.1/?.lua;/workspaces/Grafana-Query-Cache/?.lua"

RUN chmod u+x /opt/entrypoint.sh
CMD ["/opt/entrypoint.sh", "start"]