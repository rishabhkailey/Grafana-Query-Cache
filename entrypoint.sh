#!/bin/bash

function init() {
    # default values
    export GRAFANA_HOST=${GRAFANA_HOST:-"localhost:3000"}
    export GRAFANA_SCHEME=${GRAFANA_SCHEME:-"http"}
    export MAX_CACHE_SIZE=${MAX_CACHE_SIZE:-"1g"}
    export KEY_ZONE_SIZE=${KEY_ZONE_SIZE:-"10m"}
    export MAX_INACTIVE_TIME=${MAX_INACTIVE_TIME:-"10m"}
    export CACHE_EXPIRE_TIME=${CACHE_EXPIRE_TIME:-"60m"}
    export CACHE_DIRECTORY=${CACHE_DIRECTORY:-"/var/lib/nginx/cache"}
    export CACHE_VERSION=${CACHE_VERSION:-"1"}
    export SERVER_NAME=${SERVER_NAME:-"_"}
    export LISTEN=${LISTEN:-"80"}
    export SSL=${SSL:-"off"}
    export SSL_CERTIFICATE=${SSL_CERTIFICATE:-""}
    export SSL_CERTIFICATE_KEY=${SSL_CERTIFICATE_KEY:-""}
    export SSL_PROTOCOLS=${SSL_PROTOCOLS:-"TLSv1 TLSv1.1 TLSv1.2 TLSv1.3"}
    export SSL_CIPHERS=${SSL_CIPHERS:-"HIGH:!aNULL:!MD5"}
    export SSL_PASSWORD_FILE=${SSL_PASSWORD_FILE:-""}
    export CLIENT_MAX_BODY_SIZE=${CLIENT_MAX_BODY_SIZE:-"5m"}

    export ENV_VARIABLES_LIST='$GRAFANA_HOST, $GRAFANA_SCHEME, $MAX_CACHE_SIZE, $KEY_ZONE_SIZE, $MAX_INACTIVE_TIME, $CACHE_EXPIRE_TIME, $CACHE_DIRECTORY, $CACHE_VERSION, $SERVER_NAME, $LISTEN, $SSL, $SSL_CERTIFICATE, $SSL_CERTIFICATE_KEY, $SSL_PROTOCOLS, $SSL_CIPHERS, $SSL_CONFIG, $CLIENT_MAX_BODY_SIZE'

    mkdir -p "${CACHE_DIRECTORY}"
}

function genrate_nginx_conf() {
    if [ "$SSL" = "on" ]; then
        SSL_CONFIG=$(/bin/bash /etc/nginx/templates/ssl-conf.sh)
        exit_code=$?
        if [ $exit_code -ne 0 ]; then
            echo "failed to substitute env variables for ssl config";
            exit 1;
        fi
        export SSL_CONFIG
    fi

    envsubst "$ENV_VARIABLES_LIST" < /etc/nginx/templates/grafana.conf > /etc/nginx/conf.d/grafana.conf
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "failed to substitute env variables for nginx variable"
        exit 1
    fi

    nginx -t
    if [ $exit_code -ne 0 ]; then
        echo "invalid nginx config"
        exit 1
    fi

}

function start_nginx() {
    /usr/bin/openresty -g 'daemon off;'
}

init
genrate_nginx_conf
start_nginx
