#!/bin/bash
#
# Bitnami ZooKeeper library

# shellcheck disable=SC1091

# Load Generic Libraries
. /opt/bitnami/scripts/libfile.sh
. /opt/bitnami/scripts/libfs.sh
. /opt/bitnami/scripts/liblog.sh
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/libvalidations.sh

# Functions

########################
# Load global variables used on ZooKeeper configuration
# Globals:
#   ZOO_*
# Arguments:
#   None
# Returns:
#   Series of exports to be used as 'eval' arguments
#########################
zookeeper_env() {
    cat <<"EOF"
# Format log messages
export MODULE=zookeeper
export BITNAMI_DEBUG=${BITNAMI_DEBUG:-false}

# Paths
export ZOO_BASE_DIR="/opt/bitnami/zookeeper"
export ZOO_DATA_DIR="/bitnami/zookeeper/data"
export ZOO_DATA_LOG_DIR="${ZOO_DATA_LOG_DIR:-}"
export ZOO_CONF_DIR="${ZOO_BASE_DIR}/conf"
export ZOO_CONF_FILE="${ZOO_CONF_DIR}/zoo.cfg"
export ZOO_LOG_DIR="${ZOO_BASE_DIR}/logs"
export ZOO_BIN_DIR="${ZOO_BASE_DIR}/bin"

# Users
export ZOO_DAEMON_USER="zookeeper"
export ZOO_DAEMON_GROUP="zookeeper"

# Cluster configuration
export ZOO_PORT_NUMBER="${ZOO_PORT_NUMBER:-2181}"
export ZOO_SERVER_ID="${ZOO_SERVER_ID:-1}"
export ZOO_SERVERS="${ZOO_SERVERS:-}"

# Zookeeper settings
export ZOO_TICK_TIME="${ZOO_TICK_TIME:-2000}"
export ZOO_INIT_LIMIT="${ZOO_INIT_LIMIT:-10}"
export ZOO_SYNC_LIMIT="${ZOO_SYNC_LIMIT:-5}"
export ZOO_MAX_CNXNS="${ZOO_MAX_CNXNS:-0}"
export ZOO_MAX_CLIENT_CNXNS="${ZOO_MAX_CLIENT_CNXNS:-60}"
export ZOO_AUTOPURGE_INTERVAL="${ZOO_AUTOPURGE_INTERVAL:-0}"
export ZOO_AUTOPURGE_RETAIN_COUNT="${ZOO_AUTOPURGE_RETAIN_COUNT:-3}"
export ZOO_LOG_LEVEL="${ZOO_LOG_LEVEL:-INFO}"
export ZOO_4LW_COMMANDS_WHITELIST="${ZOO_4LW_COMMANDS_WHITELIST:-srvr, mntr}"
export ZOO_RECONFIG_ENABLED="${ZOO_RECONFIG_ENABLED:-no}"
export ZOO_LISTEN_ALLIPS_ENABLED="${ZOO_LISTEN_ALLIPS_ENABLED:-no}"
export ZOO_ENABLE_PROMETHEUS_METRICS="${ZOO_ENABLE_PROMETHEUS_METRICS:-no}"
export ZOO_PROMETHEUS_METRICS_PORT_NUMBER="${ZOO_PROMETHEUS_METRICS_PORT_NUMBER:-7000}"
export ZOO_MAX_SESSION_TIMEOUT="${ZOO_MAX_SESSION_TIMEOUT:-40000}"

# Zookeeper TLS Settings
export ZOO_TLS_CLIENT_ENABLE="${ZOO_TLS_CLIENT_ENABLE:-false}"
export ZOO_TLS_PORT_NUMBER="${ZOO_TLS_PORT_NUMBER:-3181}"
export ZOO_TLS_CLIENT_KEYSTORE_FILE="${ZOO_TLS_CLIENT_KEYSTORE_FILE:-}"
export ZOO_TLS_CLIENT_KEYSTORE_PASSWORD="${ZOO_TLS_CLIENT_KEYSTORE_PASSWORD:-}"
export ZOO_TLS_CLIENT_TRUSTSTORE_FILE="${ZOO_TLS_CLIENT_TRUSTSTORE_FILE:-}"
export ZOO_TLS_CLIENT_TRUSTSTORE_PASSWORD="${ZOO_TLS_CLIENT_TRUSTSTORE_PASSWORD:-}"
export ZOO_TLS_QUORUM_ENABLE="${ZOO_TLS_QUORUM_ENABLE:-false}"
export ZOO_TLS_QUORUM_KEYSTORE_FILE="${ZOO_TLS_QUORUM_KEYSTORE_FILE:-}"
export ZOO_TLS_QUORUM_KEYSTORE_PASSWORD="${ZOO_TLS_QUORUM_KEYSTORE_PASSWORD:-}"
export ZOO_TLS_QUORUM_TRUSTSTORE_FILE="${ZOO_TLS_QUORUM_TRUSTSTORE_FILE:-}"
export ZOO_TLS_QUORUM_TRUSTSTORE_PASSWORD="${ZOO_TLS_QUORUM_TRUSTSTORE_PASSWORD:-}"

# Java settings
export JVMFLAGS="${JVMFLAGS:-}"
export ZOO_HEAP_SIZE="${ZOO_HEAP_SIZE:-1024}"

# Authentication
export ALLOW_ANONYMOUS_LOGIN="${ALLOW_ANONYMOUS_LOGIN:-no}"
export ZOO_ENABLE_AUTH="${ZOO_ENABLE_AUTH:-no}"
export ZOO_CLIENT_USER="${ZOO_CLIENT_USER:-}"
export ZOO_SERVER_USERS="${ZOO_SERVER_USERS:-}"
EOF
    if [[ -f "${ZOO_CLIENT_PASSWORD_FILE:-}" ]]; then
        cat <<"EOF"
export ZOO_CLIENT_PASSWORD="$(< "${ZOO_CLIENT_PASSWORD_FILE}")"
EOF
    else
        cat <<"EOF"
export ZOO_CLIENT_PASSWORD="${ZOO_CLIENT_PASSWORD:-}"
EOF
    fi
    if [[ -f "${ZOO_SERVER_PASSWORDS_FILE:-}" ]]; then
        cat <<"EOF"
export ZOO_SERVER_PASSWORDS="$(< "${ZOO_SERVER_PASSWORDS_FILE}")"
EOF
    else
        cat <<"EOF"
export ZOO_SERVER_PASSWORDS="${ZOO_SERVER_PASSWORDS:-}"
EOF
    fi
}

########################
# Validate settings in ZOO_* env vars
# Globals:
#   ZOO_*
# Arguments:
#   None
# Returns:
#   None
#########################
zookeeper_validate() {
    local error_code=0
    debug "Validating settings in ZOO_* env vars..."

    # Auxiliary functions
    print_validation_error() {
        error "$1"
        error_code=1
    }

    # ZooKeeper authentication validations
    if is_boolean_yes "$ALLOW_ANONYMOUS_LOGIN"; then
        warn "You have set the environment variable ALLOW_ANONYMOUS_LOGIN=${ALLOW_ANONYMOUS_LOGIN}. For safety reasons, do not use this flag in a production environment."
    elif ! is_boolean_yes "$ZOO_ENABLE_AUTH"; then
        print_validation_error "The ZOO_ENABLE_AUTH environment variable does not configure authentication. Set the environment variable ALLOW_ANONYMOUS_LOGIN=yes to allow unauthenticated users to connect to ZooKeeper."
    fi

    # ZooKeeper port validations
    check_conflicting_ports() {
        local -r total="$#"

        for i in $(seq 1 "$((total - 1))"); do
            for j in $(seq "$((i + 1))" "$total"); do
                if (( "${!i}" == "${!j}" )); then
                    print_validation_error "${!i} and ${!j} are bound to the same port"
                fi
            done
        done
    }

    check_allowed_port() {
        local validate_port_args="-unprivileged"

        if ! err=$(validate_port "${validate_port_args[@]}" "${!1}"); then
            print_validation_error "An invalid port was specified in the environment variable $1: $err"
        fi
    }

    check_allowed_port ZOO_PORT_NUMBER
    check_allowed_port ZOO_PROMETHEUS_METRICS_PORT_NUMBER

    check_conflicting_ports ZOO_PORT_NUMBER ZOO_PROMETHEUS_METRICS_PORT_NUMBER

    # ZooKeeper server users validations
    read -r -a server_users_list <<< "${ZOO_SERVER_USERS//[;, ]/ }"
    read -r -a server_passwords_list <<< "${ZOO_SERVER_PASSWORDS//[;, ]/ }"
    if [[ ${#server_users_list[@]} -ne ${#server_passwords_list[@]} ]]; then
        print_validation_error "ZOO_SERVER_USERS and ZOO_SERVER_PASSWORDS lists should have the same length"
    fi

    # ZooKeeper server list validations
    if [[ -n $ZOO_SERVERS ]]; then
        server_id_with_jumps="no"
        [[ "$ZOO_SERVERS" == *"::"* ]] && server_id_with_jumps="yes"
        read -r -a zookeeper_servers_list <<< "${ZOO_SERVERS//[;, ]/ }"
        for server in "${zookeeper_servers_list[@]}"; do
            if  is_boolean_yes "$server_id_with_jumps"; then
                if ! echo "$server" | grep -q -E "^[^:]+:[^:]+:[^:]+::[1-9][0-9]*$"; then
                    print_validation_error "Zookeeper server ${server} should follow the next syntax: host:port:port::id. Example: zookeeper:2888:3888::1"
                fi
            else
                if ! echo "$server" | grep -q -E "^[^:]+:[^:]+:[^:]+$"; then
                    print_validation_error "Zookeeper server ${server} should follow the next syntax: host:port:port. Example: zookeeper:2888:3888"
                fi
            fi
        done
    fi

    [[ "$error_code" -eq 0 ]] || exit "$error_code"
}

########################
# Ensure ZooKeeper is initialized
# Globals:
#   ZOO_*
# Arguments:
#   None
# Returns:
#   None
#########################
zookeeper_initialize() {
    info "Initializing ZooKeeper..."

    if [[ ! -f "$ZOO_CONF_FILE" ]]; then
        info "No injected configuration file found, creating default config files..."
        zookeeper_generate_conf
        zookeeper_configure_heap_size "$ZOO_HEAP_SIZE"
        if is_boolean_yes "$ZOO_ENABLE_AUTH"; then
            zookeeper_enable_authentication "$ZOO_CONF_FILE"
            zookeeper_create_jaas_file
        fi
        if is_boolean_yes "$ZOO_ENABLE_PROMETHEUS_METRICS"; then
            zookeeper_enable_prometheus_metrics "$ZOO_CONF_FILE"
        fi
    else
        info "User injected custom configuration detected!"
    fi

    if is_dir_empty "$ZOO_DATA_DIR"; then
        info "Deploying ZooKeeper from scratch..."
        echo "$ZOO_SERVER_ID" > "${ZOO_DATA_DIR}/myid"

        if is_boolean_yes "$ZOO_ENABLE_AUTH" && [[ $ZOO_SERVER_ID -eq 1 ]] && [[ -n $ZOO_SERVER_USERS ]]; then
            zookeeper_configure_acl
        fi
    else
        info "Deploying ZooKeeper with persisted data..."
    fi
}

########################
# Generate the configuration files for ZooKeeper
# Globals:
#   ZOO_*
# Arguments:
#   None
# Returns:
#   None
#########################
zookeeper_generate_conf() {
    cp "${ZOO_CONF_DIR}/zoo_sample.cfg" "$ZOO_CONF_FILE"
    echo >> "$ZOO_CONF_FILE"

    zookeeper_conf_set "$ZOO_CONF_FILE" tickTime "$ZOO_TICK_TIME"
    zookeeper_conf_set "$ZOO_CONF_FILE" initLimit "$ZOO_INIT_LIMIT"
    zookeeper_conf_set "$ZOO_CONF_FILE" syncLimit "$ZOO_SYNC_LIMIT"
    zookeeper_conf_set "$ZOO_CONF_FILE" dataDir "$ZOO_DATA_DIR"
    [[ -n "$ZOO_DATA_LOG_DIR" ]] && zookeeper_conf_set "$ZOO_CONF_FILE" dataLogDir "$ZOO_DATA_LOG_DIR"
    zookeeper_conf_set "$ZOO_CONF_FILE" clientPort "$ZOO_PORT_NUMBER"
    zookeeper_conf_set "$ZOO_CONF_FILE" maxCnxns "$ZOO_MAX_CNXNS"
    zookeeper_conf_set "$ZOO_CONF_FILE" maxClientCnxns "$ZOO_MAX_CLIENT_CNXNS"
    zookeeper_conf_set "$ZOO_CONF_FILE" reconfigEnabled "$(is_boolean_yes "$ZOO_RECONFIG_ENABLED" && echo true || echo false)"
    zookeeper_conf_set "$ZOO_CONF_FILE" quorumListenOnAllIPs "$(is_boolean_yes "$ZOO_LISTEN_ALLIPS_ENABLED" && echo true || echo false)"
    zookeeper_conf_set "$ZOO_CONF_FILE" autopurge.purgeInterval "$ZOO_AUTOPURGE_INTERVAL"
    zookeeper_conf_set "$ZOO_CONF_FILE" autopurge.snapRetainCount "$ZOO_AUTOPURGE_RETAIN_COUNT"
    zookeeper_conf_set "$ZOO_CONF_FILE" 4lw.commands.whitelist "$ZOO_4LW_COMMANDS_WHITELIST"
    zookeeper_conf_set "$ZOO_CONF_FILE" maxSessionTimeout "$ZOO_MAX_SESSION_TIMEOUT"
    # Set log level
    zookeeper_conf_set "${ZOO_CONF_DIR}/log4j.properties" zookeeper.console.threshold "$ZOO_LOG_LEVEL"

    # Add zookeeper servers to configuration
    server_id_with_jumps="no"
    [[ "$ZOO_SERVERS" == *"::"* ]] && server_id_with_jumps="yes"
    read -r -a zookeeper_servers_list <<< "${ZOO_SERVERS//[;, ]/ }"
    if [[ ${#zookeeper_servers_list[@]} -gt 1 ]]; then
        if is_boolean_yes "$server_id_with_jumps"; then
            for server in "${zookeeper_servers_list[@]}"; do
                read -r -a srv <<< "${server//::/ }"
                info "Adding server: ${srv[0]} with id: ${srv[1]}"
                zookeeper_conf_set "$ZOO_CONF_FILE" "server.${srv[1]}" "${srv[0]};${ZOO_PORT_NUMBER}"
            done
        else
            local i=1
            for server in "${zookeeper_servers_list[@]}"; do
                info "Adding server: ${server}"
                zookeeper_conf_set "$ZOO_CONF_FILE" "server.$i" "${server};${ZOO_PORT_NUMBER}"
                (( i++ ))
            done
        fi
    else
        info "No additional servers were specified. ZooKeeper will run in standalone mode..."
    fi

    # If TLS in enable
    if is_boolean_yes "$ZOO_TLS_CLIENT_ENABLE"; then
        zookeeper_conf_set "$ZOO_CONF_FILE" client.secure true
        zookeeper_conf_set "$ZOO_CONF_FILE" secureClientPort "$ZOO_TLS_PORT_NUMBER"
        zookeeper_conf_set "$ZOO_CONF_FILE" serverCnxnFactory org.apache.zookeeper.server.NettyServerCnxnFactory
        [[ -n "$ZOO_TLS_CLIENT_KEYSTORE_PASSWORD" ]] && zookeeper_conf_set "$ZOO_CONF_FILE" ssl.keyStore.password "$ZOO_TLS_CLIENT_KEYSTORE_PASSWORD"
        zookeeper_conf_set "$ZOO_CONF_FILE" ssl.keyStore.location "$ZOO_TLS_CLIENT_KEYSTORE_FILE"
        [[ -n "$ZOO_TLS_CLIENT_TRUSTSTORE_PASSWORD" ]] && zookeeper_conf_set "$ZOO_CONF_FILE" ssl.trustStore.password "$ZOO_TLS_CLIENT_TRUSTSTORE_PASSWORD"
        zookeeper_conf_set "$ZOO_CONF_FILE" ssl.trustStore.location "$ZOO_TLS_CLIENT_TRUSTSTORE_FILE"
    fi
    if is_boolean_yes "$ZOO_TLS_QUORUM_ENABLE"; then
        zookeeper_conf_set "$ZOO_CONF_FILE" sslQuorum true
        zookeeper_conf_set "$ZOO_CONF_FILE" serverCnxnFactory org.apache.zookeeper.server.NettyServerCnxnFactory
        zookeeper_conf_set "$ZOO_CONF_FILE" ssl.quorum.keyStore.location "$ZOO_TLS_QUORUM_KEYSTORE_FILE"
        [[ -n "$ZOO_TLS_QUORUM_KEYSTORE_PASSWORD" ]] && zookeeper_conf_set "$ZOO_CONF_FILE" ssl.quorum.keyStore.password "$ZOO_TLS_QUORUM_KEYSTORE_PASSWORD"
        zookeeper_conf_set "$ZOO_CONF_FILE" ssl.quorum.trustStore.location "$ZOO_TLS_QUORUM_TRUSTSTORE_FILE"
        [[ -n "$ZOO_TLS_QUORUM_TRUSTSTORE_PASSWORD" ]] && zookeeper_conf_set "$ZOO_CONF_FILE" ssl.quorum.trustStore.password "$ZOO_TLS_QUORUM_TRUSTSTORE_PASSWORD"
    fi
}

########################
# Configure heap size
# Globals:
#   JVMFLAGS
# Arguments:
#   $1 - heap_size
# Returns:
#   None
#########################
zookeeper_configure_heap_size() {
    local -r heap_size="${1:?heap_size is required}"

    if [[ "$JVMFLAGS" =~ -Xm[xs].*-Xm[xs] ]]; then
        debug "Using specified values (JVMFLAGS=${JVMFLAGS})"
    else
        debug "Setting '-Xmx${heap_size}m -Xms${heap_size}m' heap options..."
        zookeeper_export_jvmflags "-Xmx${heap_size}m -Xms${heap_size}m"
    fi
}

########################
# Enable authentication for ZooKeeper
# Globals:
#   None
# Arguments:
#   $1 - filename
# Returns:
#   None
#########################
zookeeper_enable_authentication() {
    local -r filename="${1:?filename is required}"

    info "Enabling authentication..."
    zookeeper_conf_set "$filename" authProvider.1 org.apache.zookeeper.server.auth.SASLAuthenticationProvider
    zookeeper_conf_set "$filename" requireClientAuthScheme sasl
}

########################
# Enable Prometheus metrics for ZooKeeper
# Globals:
#   ZOO_PROMETHEUS_METRICS_PORT_NUMBER
# Arguments:
#   $1 - filename
# Returns:
#   None
#########################
zookeeper_enable_prometheus_metrics() {
    local -r filename="${1:?filename is required}"

    info "Enabling Prometheus metrics..."
    zookeeper_conf_set "$filename" metricsProvider.className org.apache.zookeeper.metrics.prometheus.PrometheusMetricsProvider
    zookeeper_conf_set "$filename" metricsProvider.httpPort "$ZOO_PROMETHEUS_METRICS_PORT_NUMBER"
    zookeeper_conf_set "$filename" metricsProvider.exportJvmInfo true
}

########################
# Set a configuration setting value into a configuration file
# Globals:
#   None
# Arguments:
#   $1 - filename
#   $2 - key
#   $3 - value
# Returns:
#   None
#########################
zookeeper_conf_set() {
    local -r filename="${1:?filename is required}"
    local -r key="${2:?key is required}"
    local -r value="${3:?value is required}"

    if grep -q -E "^\s*#*\s*${key}=" "$filename"; then
        replace_in_file "$filename" "^\s*#*\s*${key}=.*" "${key}=${value}"
    else
        echo "${key}=${value}" >> "$filename"
    fi
}

########################
# Create a JAAS file for authentication
# Globals:
#   JVMFLAGS, ZOO_*
# Arguments:
#   None
# Returns:
#   None
#########################
zookeeper_create_jaas_file() {
    info "Creating jaas file..."
    read -r -a server_users_list <<< "${ZOO_SERVER_USERS//[;, ]/ }"
    read -r -a server_passwords_list <<< "${ZOO_SERVER_PASSWORDS//[;, ]/ }"

    local zookeeper_server_user_passwords=""
    for i in $(seq 0 $(( ${#server_users_list[@]} - 1 ))); do
        zookeeper_server_user_passwords="${zookeeper_server_user_passwords}\n   user_${server_users_list[i]}=\"${server_passwords_list[i]}\""
    done
    zookeeper_server_user_passwords="${zookeeper_server_user_passwords#\\n   };"

    cat >"${ZOO_CONF_DIR}/zoo_jaas.conf" <<EOF
Client {
    org.apache.zookeeper.server.auth.DigestLoginModule required
    username="$ZOO_CLIENT_USER"
    password="$ZOO_CLIENT_PASSWORD";
};
Server {
    org.apache.zookeeper.server.auth.DigestLoginModule required
    $(echo -e -n "${zookeeper_server_user_passwords}")
};
EOF
    zookeeper_export_jvmflags "-Djava.security.auth.login.config=${ZOO_CONF_DIR}/zoo_jaas.conf"

    # Restrict file permissions
    am_i_root && owned_by "${ZOO_CONF_DIR}/zoo_jaas.conf" "$ZOO_DAEMON_USER"
    chmod 400 "${ZOO_CONF_DIR}/zoo_jaas.conf"
}

########################
# Configures ACL settings
# Globals:
#   ZOO_*
# Arguments:
#   None
# Returns:
#   None
#########################
zookeeper_configure_acl() {
    local acl_string=""
    for server_user in ${ZOO_SERVER_USERS//[;, ]/ }; do
        acl_string="${acl_string},sasl:${server_user}:crdwa"
    done
    acl_string="${acl_string#,}"

    zookeeper_start_bg

    for path in / /zookeeper /zookeeper/quota; do
        info "Setting the ACL rule '${acl_string}' in ${path}"
        retry_while "${ZOO_BIN_DIR}/zkCli.sh setAcl ${path} ${acl_string}" 80
    done

    zookeeper_stop
    mv "${ZOO_LOG_DIR}/zookeeper.out" "${ZOO_LOG_DIR}/zookeeper.out.firstboot"
}

########################
# Export JVMFLAGS
# Globals:
#   JVMFLAGS
# Arguments:
#   $1 - value
# Returns:
#   None
#########################
zookeeper_export_jvmflags() {
    local -r value="${1:?value is required}"

    export JVMFLAGS="${JVMFLAGS} ${value}"
    echo "export JVMFLAGS=\"${JVMFLAGS}\"" > "${ZOO_CONF_DIR}/java.env"
}

########################
# Start ZooKeeper in background mode and waits until it's ready
# Globals:
#   ZOO_*
# Arguments:
#   None
# Returns:
#   None
#########################
zookeeper_start_bg() {
    local cmd="${ZOO_BIN_DIR}/zkServer.sh"
    local args=("start")
    info "Starting ZooKeeper in background..."
    if am_i_root; then
        debug_execute "gosu" "$ZOO_DAEMON_USER" "$cmd" "${args[@]}"
    else
        debug_execute "$cmd" "${args[@]}"
    fi
    wait-for-port --timeout 60 "$ZOO_PORT_NUMBER"
}

########################
# Stop ZooKeeper
# Globals:
#   ZOO_*
# Arguments:
#   None
# Returns:
#   None
#########################
zookeeper_stop() {
    info "Stopping ZooKeeper..."
    debug_execute "${ZOO_BIN_DIR}/zkServer.sh" stop
}

########################
# Ensure a smooth transition to Bash logic in Helm Chart deployments.
# See https://github.com/bitnami/charts/pull/1390/files#diff-6b063ad92827264b128cc05c45bd9232L85-L90
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
#########################
zookeeper_ensure_backwards_compatibility() {
    mkdir -p "/opt/bitnami/base"
    cat > "/opt/bitnami/base/functions" <<EOF
#!/bin/bash

# Load Generic Libraries
. /opt/bitnami/scripts/liblog.sh

warn "You are probably using an old version of the bitnami/zookeeper Helm Chart. Please consider upgrading to 5.0.0 or later."

exec /opt/bitnami/scripts/entrypoint.sh /opt/bitnami/scripts/run.sh
EOF
}
