#!/bin/bash

function init_variables() {
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
    export NGINX_CONFIG_TEMPLATE_DIRECTORY=${NGINX_CONFIG_TEMPLATE_DIRECTORY:-"/etc/nginx/templates"}
    export NGINX_CONFIG_OUTPUT_FILE=${NGINX_CONFIG_OUTPUT_FILE:-"/etc/nginx/conf.d/grafana.conf"}
    export DEBUG_IP_CADR=${DEBUG_IP_CADR:-"127.0.0.1/32"}
    export MIN_REQUEST_COUNT=${MIN_REQUEST_COUNT:-"2"}

    export ENV_VARIABLES_LIST='$GRAFANA_HOST, $GRAFANA_SCHEME, $MAX_CACHE_SIZE, $KEY_ZONE_SIZE, $MAX_INACTIVE_TIME, $CACHE_EXPIRE_TIME, $CACHE_DIRECTORY, $CACHE_VERSION, $SERVER_NAME, $LISTEN, $SSL, $SSL_CERTIFICATE, $SSL_CERTIFICATE_KEY, $SSL_PROTOCOLS, $SSL_CIPHERS, $SSL_CONFIG, $CLIENT_MAX_BODY_SIZE, $DEBUG_IP_CADR, $MIN_REQUEST_COUNT'

    mkdir -p "${CACHE_DIRECTORY}"
}

function genrate_nginx_conf() {
    if [ "$SSL" = "on" ]; then
        SSL_CONFIG=$(/bin/bash ${NGINX_CONFIG_TEMPLATE_DIRECTORY}/ssl-conf.sh)
        exit_code=$?
        if [ $exit_code -ne 0 ]; then
            echo "failed to substitute env variables for ssl config";
            return 1;
        fi
        export SSL_CONFIG
    fi

    envsubst "$ENV_VARIABLES_LIST" < ${NGINX_CONFIG_TEMPLATE_DIRECTORY}/grafana.conf > ${NGINX_CONFIG_OUTPUT_FILE}
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "failed to substitute env variables for nginx variable"
        return $exit_code
    fi

}

function init() {
    init_variables
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "init variables failed"
        return $exit_code
    fi
    genrate_nginx_conf
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "generate nginx conf failed"
        return $exit_code
    fi
}

function config_test() {
    nginx -t
    if [ $exit_code -ne 0 ]; then
        echo "invalid nginx config"
        return $exit_code
    fi
}

function start_nginx() {
    config_test
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "nginx config test failed"
        return $exit_code
    fi
    /usr/bin/openresty -g 'daemon off;'
}

function main() {
    init
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "init failed"
        exit $exit_code
    fi
    exit_code=0
    if [ "$1" == "test" ]; then
        config_test
        exit_code=$?
    elif [ "$1" == "start" ]; then
        start_nginx
        exit_code=$?
    else
        echo "Valid options are: test and start"
        exit_code=1
    fi

    exit $exit_code
}

main $1