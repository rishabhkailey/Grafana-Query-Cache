FROM openresty/openresty:1.25.3.1-0-bookworm-fat

RUN rm /etc/nginx/conf.d/default.conf || true && \
    apt update && apt install -y luarocks=3.8.0+dfsg1-1 gettext-base=0.21-12 libyaml-dev=0.2.5-1

WORKDIR /etc/grafana-query-cache
COPY rocks.txt scripts/install-packages.sh .
RUN chmod u+x ./install-packages.sh && \
    /bin/bash ./install-packages.sh rocks.txt && \
    apt-get remove -y --purge luarocks && apt autoremove -y

RUN mkdir -p /etc/grafana-query-cache/templates
COPY src/grafana_request.lua src/set_cache_key.lua src/utils.lua src/config.lua scripts/entrypoint.sh config/cache_rules.yaml /etc/grafana-query-cache
COPY config/nginx/grafana.conf config/nginx/generate-ssl-conf.sh /etc/grafana-query-cache/templates

ENV LUA_CPATH=";;/usr/local/openresty/lualib/?.so;/usr/local/openresty/site/lualib/?.so;/usr/local/lib/lua/5.1/?.so;"
ENV LUA_PATH=";;/etc/grafana-query-cache/?.lua;/usr/local/openresty/lualib/?.lua;/usr/local/openresty/site/lualib/?.lua;//usr/local/lib/lua/5.1?.lua;/usr/local/share/lua/5.1/?.lua;/workspaces/Grafana-Query-Cache/?.lua;"

RUN chmod u+x /etc/grafana-query-cache/entrypoint.sh
CMD ["/etc/grafana-query-cache/entrypoint.sh", "start"]