FROM openresty/openresty:1.25.3.1-0-bookworm-fat

RUN rm /etc/nginx/conf.d/default.conf || true && \
    apt update && apt install -y luarocks=3.8.0+dfsg1-1 gettext-base=0.21-12 libyaml-dev=0.2.5-1 && \
    opm get ledgetech/lua-resty-http=0.17.1 && \
    luarocks install md5 1.3-1 && \
    luarocks install lyaml 6.2.8-1 && \
    apt-get remove -y --purge luarocks && apt autoremove -y

RUN mkdir -p /etc/grafana-query-cache/templates
COPY grafana_request.lua set_cache_key.lua utils.lua config.lua config.lua entrypoint.sh cache_rules.yaml /etc/grafana-query-cache
COPY grafana.conf ssl-conf.sh /etc/grafana-query-cache/templates

ENV LUA_CPATH=";;/usr/local/openresty/lualib/?.so;/usr/local/openresty/site/lualib/?.so;/usr/local/lib/lua/5.1/?.so;"
ENV LUA_PATH=";;/etc/grafana-query-cache/?.lua;/usr/local/openresty/lualib/?.lua;/usr/local/openresty/site/lualib/?.lua;//usr/local/lib/lua/5.1?.lua;/usr/local/share/lua/5.1/?.lua;/workspaces/Grafana-Query-Cache/?.lua;"

RUN chmod u+x /etc/grafana-query-cache/entrypoint.sh
CMD ["/etc/grafana-query-cache/entrypoint.sh", "start"]