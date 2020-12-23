#!/bin/bash

set -e

if [ "$DOCKER_DEBUG" = "1" ]; then
    set -x
fi

if [ -z "$PROJECT_PATH" ]; then
    PROJECT_PATH="$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

docker_main() {
    DOC="USAGE:
    docker [options] clean --i-am-not-running-this-on-a-server
    docker [options] build --all
    docker [options] build SERVICE
    docker [options] env
    docker [options] exec SERVICE [-- SERVICEARGS...]
    docker [options] ip SERVICE
    docker [options] logs SERVICE [-- DOCKERARGS...]
    docker [options] run SERVICE [-- SERVICEARGS...]
    docker [options] save SERVICE OUTPUT_FILE
    docker [options] stop SERVICE
    docker [options] stop --all
    docker [options] ps [-- DOCKERARGS...]
    docker [options] [up] [--no-client] SERVICE

Options:
    --no-build    Don't build container upon running *up*
    --production  Execute commands as if in production environment

Up options:
    --no-client   Run container without tailing logs, this automatically
                  switches the log driver to journald. The \$UNIT environment
                  variable is expected to be set.

Examples:
    Start a shell inside a running postgres container
        docker exec postgres
    Start a node process inside a running graphql-server
        docker exec graphql node
    Run lint script in a new container based on graphql service image
        docker run graphql yarn lint
"
# docopt parser below, refresh this parser with `docopt.sh docker`
# shellcheck disable=2016,1075,2154
docopt() { parse() { if ${DOCOPT_DOC_CHECK:-true}; then local doc_hash
if doc_hash=$(printf "%s" "$DOC" | (sha256sum 2>/dev/null || shasum -a 256)); then
if [[ ${doc_hash:0:5} != "$digest" ]]; then
stderr "The current usage doc (${doc_hash:0:5}) does not match \
what the parser was generated with (${digest})
Run \`docopt.sh\` to refresh the parser."; _return 70; fi; fi; fi
local root_idx=$1; shift; argv=("$@"); parsed_params=(); parsed_values=()
left=(); testdepth=0; local arg; while [[ ${#argv[@]} -gt 0 ]]; do
if [[ ${argv[0]} = "--" ]]; then for arg in "${argv[@]}"; do
parsed_params+=('a'); parsed_values+=("$arg"); done; break
elif [[ ${argv[0]} = --* ]]; then parse_long
elif [[ ${argv[0]} = -* && ${argv[0]} != "-" ]]; then parse_shorts
elif ${DOCOPT_OPTIONS_FIRST:-false}; then for arg in "${argv[@]}"; do
parsed_params+=('a'); parsed_values+=("$arg"); done; break; else
parsed_params+=('a'); parsed_values+=("${argv[0]}"); argv=("${argv[@]:1}"); fi
done; local idx; if ${DOCOPT_ADD_HELP:-true}; then
for idx in "${parsed_params[@]}"; do [[ $idx = 'a' ]] && continue
if [[ ${shorts[$idx]} = "-h" || ${longs[$idx]} = "--help" ]]; then
stdout "$trimmed_doc"; _return 0; fi; done; fi
if [[ ${DOCOPT_PROGRAM_VERSION:-false} != 'false' ]]; then
for idx in "${parsed_params[@]}"; do [[ $idx = 'a' ]] && continue
if [[ ${longs[$idx]} = "--version" ]]; then stdout "$DOCOPT_PROGRAM_VERSION"
_return 0; fi; done; fi; local i=0; while [[ $i -lt ${#parsed_params[@]} ]]; do
left+=("$i"); ((i++)) || true; done
if ! required "$root_idx" || [ ${#left[@]} -gt 0 ]; then error; fi; return 0; }
parse_shorts() { local token=${argv[0]}; local value; argv=("${argv[@]:1}")
[[ $token = -* && $token != --* ]] || _return 88; local remaining=${token#-}
while [[ -n $remaining ]]; do local short="-${remaining:0:1}"
remaining="${remaining:1}"; local i=0; local similar=(); local match=false
for o in "${shorts[@]}"; do if [[ $o = "$short" ]]; then similar+=("$short")
[[ $match = false ]] && match=$i; fi; ((i++)) || true; done
if [[ ${#similar[@]} -gt 1 ]]; then
error "${short} is specified ambiguously ${#similar[@]} times"
elif [[ ${#similar[@]} -lt 1 ]]; then match=${#shorts[@]}; value=true
shorts+=("$short"); longs+=(''); argcounts+=(0); else value=false
if [[ ${argcounts[$match]} -ne 0 ]]; then if [[ $remaining = '' ]]; then
if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
error "${short} requires argument"; fi; value=${argv[0]}; argv=("${argv[@]:1}")
else value=$remaining; remaining=''; fi; fi; if [[ $value = false ]]; then
value=true; fi; fi; parsed_params+=("$match"); parsed_values+=("$value"); done
}; parse_long() { local token=${argv[0]}; local long=${token%%=*}
local value=${token#*=}; local argcount; argv=("${argv[@]:1}")
[[ $token = --* ]] || _return 88; if [[ $token = *=* ]]; then eq='='; else eq=''
value=false; fi; local i=0; local similar=(); local match=false
for o in "${longs[@]}"; do if [[ $o = "$long" ]]; then similar+=("$long")
[[ $match = false ]] && match=$i; fi; ((i++)) || true; done
if [[ $match = false ]]; then i=0; for o in "${longs[@]}"; do
if [[ $o = $long* ]]; then similar+=("$long"); [[ $match = false ]] && match=$i
fi; ((i++)) || true; done; fi; if [[ ${#similar[@]} -gt 1 ]]; then
error "${long} is not a unique prefix: ${similar[*]}?"
elif [[ ${#similar[@]} -lt 1 ]]; then
[[ $eq = '=' ]] && argcount=1 || argcount=0; match=${#shorts[@]}
[[ $argcount -eq 0 ]] && value=true; shorts+=(''); longs+=("$long")
argcounts+=("$argcount"); else if [[ ${argcounts[$match]} -eq 0 ]]; then
if [[ $value != false ]]; then
error "${longs[$match]} must not have an argument"; fi
elif [[ $value = false ]]; then
if [[ ${#argv[@]} -eq 0 || ${argv[0]} = '--' ]]; then
error "${long} requires argument"; fi; value=${argv[0]}; argv=("${argv[@]:1}")
fi; if [[ $value = false ]]; then value=true; fi; fi; parsed_params+=("$match")
parsed_values+=("$value"); }; required() { local initial_left=("${left[@]}")
local node_idx; ((testdepth++)) || true; for node_idx in "$@"; do
if ! "node_$node_idx"; then left=("${initial_left[@]}"); ((testdepth--)) || true
return 1; fi; done; if [[ $((--testdepth)) -eq 0 ]]; then
left=("${initial_left[@]}"); for node_idx in "$@"; do "node_$node_idx"; done; fi
return 0; }; either() { local initial_left=("${left[@]}"); local best_match_idx
local match_count; local node_idx; ((testdepth++)) || true
for node_idx in "$@"; do if "node_$node_idx"; then
if [[ -z $match_count || ${#left[@]} -lt $match_count ]]; then
best_match_idx=$node_idx; match_count=${#left[@]}; fi; fi
left=("${initial_left[@]}"); done; ((testdepth--)) || true
if [[ -n $best_match_idx ]]; then "node_$best_match_idx"; return 0; fi
left=("${initial_left[@]}"); return 1; }; optional() { local node_idx
for node_idx in "$@"; do "node_$node_idx"; done; return 0; }; oneormore() {
local i=0; local prev=${#left[@]}; while "node_$1"; do ((i++)) || true
[[ $prev -eq ${#left[@]} ]] && break; prev=${#left[@]}; done
if [[ $i -ge 1 ]]; then return 0; fi; return 1; }; _command() { local i
local name=${2:-$1}; for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = 'a' ]]; then
if [[ ${parsed_values[$l]} != "$name" ]]; then return 1; fi
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; if [[ $3 = true ]]; then
eval "((var_$1++)) || true"; else eval "var_$1=true"; fi; return 0; fi; done
return 1; }; switch() { local i; for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = "$2" ]]; then
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; if [[ $3 = true ]]; then
eval "((var_$1++))" || true; else eval "var_$1=true"; fi; return 0; fi; done
return 1; }; value() { local i; for i in "${!left[@]}"; do local l=${left[$i]}
if [[ ${parsed_params[$l]} = "$2" ]]; then
left=("${left[@]:0:$i}" "${left[@]:((i+1))}")
[[ $testdepth -gt 0 ]] && return 0; local value
value=$(printf -- "%q" "${parsed_values[$l]}"); if [[ $3 = true ]]; then
eval "var_$1+=($value)"; else eval "var_$1=$value"; fi; return 0; fi; done
return 1; }; stdout() { printf -- "cat <<'EOM'\n%s\nEOM\n" "$1"; }; stderr() {
printf -- "cat <<'EOM' >&2\n%s\nEOM\n" "$1"; }; error() {
[[ -n $1 ]] && stderr "$1"; stderr "$usage"; _return 1; }; _return() {
printf -- "exit %d\n" "$1"; exit "$1"; }; set -e; trimmed_doc=${DOC:0:1196}
usage=${DOC:0:557}; digest=fcfdf; shorts=('' '' '' '' '')
longs=(--production --no-build --i-am-not-running-this-on-a-server --all --no-client)
argcounts=(0 0 0 0 0); node_0(){ switch __production 0; }; node_1(){
switch __no_build 1; }; node_2(){ switch __i_am_not_running_this_on_a_server 2
}; node_3(){ switch __all 3; }; node_4(){ switch __no_client 4; }; node_5(){
value SERVICE a; }; node_6(){ value SERVICEARGS a true; }; node_7(){
value DOCKERARGS a true; }; node_8(){ value OUTPUT_FILE a; }; node_9(){
_command clean; }; node_10(){ _command build; }; node_11(){ _command env; }
node_12(){ _command exec; }; node_13(){ _command __ --; }; node_14(){
_command ip; }; node_15(){ _command logs; }; node_16(){ _command run; }
node_17(){ _command save; }; node_18(){ _command stop; }; node_19(){ _command ps
}; node_20(){ _command up; }; node_21(){ optional 0 1; }; node_22(){ optional 21
}; node_23(){ required 22 9 2; }; node_24(){ required 22 10 3; }; node_25(){
required 22 10 5; }; node_26(){ required 22 11; }; node_27(){ oneormore 6; }
node_28(){ optional 13 27; }; node_29(){ required 22 12 5 28; }; node_30(){
required 22 14 5; }; node_31(){ oneormore 7; }; node_32(){ optional 13 31; }
node_33(){ required 22 15 5 32; }; node_34(){ required 22 16 5 28; }; node_35(){
required 22 17 5 8; }; node_36(){ required 22 18 5; }; node_37(){
required 22 18 3; }; node_38(){ required 22 19 32; }; node_39(){ optional 20; }
node_40(){ optional 4; }; node_41(){ required 22 39 40 5; }; node_42(){
either 23 24 25 26 29 30 33 34 35 36 37 38 41; }; node_43(){ required 42; }
cat <<<' docopt_exit() { [[ -n $1 ]] && printf "%s\n" "$1" >&2
printf "%s\n" "${DOC:0:557}" >&2; exit 1; }'; unset var___production \
var___no_build var___i_am_not_running_this_on_a_server var___all \
var___no_client var_SERVICE var_SERVICEARGS var_DOCKERARGS var_OUTPUT_FILE \
var_clean var_build var_env var_exec var___ var_ip var_logs var_run var_save \
var_stop var_ps var_up; parse 43 "$@"; local prefix=${DOCOPT_PREFIX:-''}
unset "${prefix}__production" "${prefix}__no_build" \
"${prefix}__i_am_not_running_this_on_a_server" "${prefix}__all" \
"${prefix}__no_client" "${prefix}SERVICE" "${prefix}SERVICEARGS" \
"${prefix}DOCKERARGS" "${prefix}OUTPUT_FILE" "${prefix}clean" "${prefix}build" \
"${prefix}env" "${prefix}exec" "${prefix}__" "${prefix}ip" "${prefix}logs" \
"${prefix}run" "${prefix}save" "${prefix}stop" "${prefix}ps" "${prefix}up"
eval "${prefix}"'__production=${var___production:-false}'
eval "${prefix}"'__no_build=${var___no_build:-false}'
eval "${prefix}"'__i_am_not_running_this_on_a_server=${var___i_am_not_running_this_on_a_server:-false}'
eval "${prefix}"'__all=${var___all:-false}'
eval "${prefix}"'__no_client=${var___no_client:-false}'
eval "${prefix}"'SERVICE=${var_SERVICE:-}'
if declare -p var_SERVICEARGS >/dev/null 2>&1; then
eval "${prefix}"'SERVICEARGS=("${var_SERVICEARGS[@]}")'; else
eval "${prefix}"'SERVICEARGS=()'; fi
if declare -p var_DOCKERARGS >/dev/null 2>&1; then
eval "${prefix}"'DOCKERARGS=("${var_DOCKERARGS[@]}")'; else
eval "${prefix}"'DOCKERARGS=()'; fi
eval "${prefix}"'OUTPUT_FILE=${var_OUTPUT_FILE:-}'
eval "${prefix}"'clean=${var_clean:-false}'
eval "${prefix}"'build=${var_build:-false}'
eval "${prefix}"'env=${var_env:-false}'
eval "${prefix}"'exec=${var_exec:-false}'; eval "${prefix}"'__=${var___:-false}'
eval "${prefix}"'ip=${var_ip:-false}'; eval "${prefix}"'logs=${var_logs:-false}'
eval "${prefix}"'run=${var_run:-false}'
eval "${prefix}"'save=${var_save:-false}'
eval "${prefix}"'stop=${var_stop:-false}'; eval "${prefix}"'ps=${var_ps:-false}'
eval "${prefix}"'up=${var_up:-false}'; local docopt_i=1
[[ $BASH_VERSION =~ ^4.3 ]] && docopt_i=2; for ((;docopt_i>0;docopt_i--)); do
declare -p "${prefix}__production" "${prefix}__no_build" \
"${prefix}__i_am_not_running_this_on_a_server" "${prefix}__all" \
"${prefix}__no_client" "${prefix}SERVICE" "${prefix}SERVICEARGS" \
"${prefix}DOCKERARGS" "${prefix}OUTPUT_FILE" "${prefix}clean" "${prefix}build" \
"${prefix}env" "${prefix}exec" "${prefix}__" "${prefix}ip" "${prefix}logs" \
"${prefix}run" "${prefix}save" "${prefix}stop" "${prefix}ps" "${prefix}up"; done
}
# docopt parser above, complete command for generating this parser is `docopt.sh docker`
    eval "$(docopt "$@")"
    load_project_env
    PROJECT_PATH_BASENAME=$(basename "$PROJECT_PATH")
    DOCKER_ENVIRONMENT=${DOCKER_ENVIRONMENT:-development}
    DOCKER_PROJECT="${DOCKER_PROJECT:-${PROJECT_PATH_BASENAME//.}}"
    DOCKER_SERVICES_PATH=${DOCKER_SERVICES_PATH:-$PROJECT_PATH/docker}

    # shellcheck disable=2154
    if $__production; then
        DOCKER_ENVIRONMENT=production
    fi

    # shellcheck disable=2153,2154
    if $env; then
        print_env
        return 0
    elif $clean; then
        if docker ps -a -q --filter 'name='"${DOCKER_PROJECT}_*"'' | wc -l | grep -vq 0; then
            # shellcheck disable=2046
            docker rm -v -f $(docker ps -a -q --filter 'name='"${DOCKER_PROJECT}_*"'') > /dev/null
        fi
        if docker images -a -q --filter 'reference='"${DOCKER_PROJECT}_*"'' | wc -l | grep -vq 0; then
            # shellcheck disable=2046
            docker rmi -f $(docker images -a -q --filter 'reference='"${DOCKER_PROJECT}_*"'') > /dev/null
        fi
        return 0
    elif [[ -n $SERVICE ]]; then
        if $ip; then
            if is_container_running "$SERVICE"; then
                local service_name
                service_name=$(get_service_name "$SERVICE")
                exec docker inspect "${service_name}" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}'
            else
                printf -- 'Warning: the %s service is not running\n' "$SERVICE" >&2
                return 1
            fi
        elif $build; then
            build_context "$SERVICE"
            docker_build "$SERVICE"
        elif $exec; then
            docker_exec "$SERVICE"
        elif $logs; then
            local service_name
            service_name=$(get_service_name "$SERVICE")
            exec docker logs "${DOCKERARGS[@]}" "$service_name"
        elif $run; then
            docker_run "$SERVICE"
        elif $save; then
            local save_tag="$service_name:latest"
            printf -- 'Saving container with tag: %s to %s\n' "$save_tag" "$OUTPUT_FILE"
            exec docker save "$save_tag" | gzip > "$OUTPUT_FILE"
        elif $stop; then
            docker_stop "$SERVICE"
        else
            if ! $__no_build; then
                build_context "$SERVICE"
                docker_build "$SERVICE" > /dev/null
            fi
            docker_up "$SERVICE" "$__no_client"
        fi
    elif $build && $__all; then
        local service
        build_context "all"
        for service in "$DOCKER_SERVICES_PATH"/*; do
            docker_build "$(basename "$service")"
        done
    elif $stop && $__all; then
        for service in "$DOCKER_SERVICES_PATH"/*; do
            docker_stop "$(basename "$service")"
        done
    elif $ps; then
        exec docker ps --filter 'name='"${DOCKER_PROJECT}_*"'' "${DOCKERARGS[@]}"
    fi
}

docker_build() {
    local build_args service_name service_path service=$1
    service_name=$(get_service_name "$service")
    service_path="$(realpath "$DOCKER_SERVICES_PATH/$service/build-context")"
    service_dockerfile=$(get_dockerfile_path "$service")
    build_args=$(get_build_args_map "$service")

    # shellcheck disable=2086
    docker build $build_args \
        --tag "$service_name:latest" \
        --file "$service_dockerfile" \
        "$service_path"
}

docker_exec() {
    local service_name service=$1

    if ! is_container_running "$service"; then
        printf -- 'Container for service %s is not running so cannot run exec\n' "$service" >&2
        return 1
    fi
    service_name=$(get_service_name "$service")

    if [[ -z "${SERVICEARGS[*]}" ]]; then
        exec docker exec -it "${service_name}" /bin/sh
    else
        exec docker exec -it "${service_name}" "${SERVICEARGS[@]}"
    fi
}

docker_run() {
    local service_name service="$1" \
          env_file tty volume_map host_map port_map net_alias=''

    [[ -t 0 ]] && tty='-it'

    service_name=$(get_service_name "$service")
    env_file=$(get_env_file "$service")

    volume_map=$(get_volumes_map "$service")
    host_map=$(get_hosts_map "$service")
    port_map=$(get_ports_map "$service")

    if [[ "$DOCKER_NETWORK" != 'bridge' ]]; then
        net_alias="--network-alias=$service "
    fi

    # shellcheck disable=2086
    exec docker run --rm $tty $env_file $net_alias $volume_map $host_map $port_map \
        --network=$DOCKER_NETWORK \
        "$service_name:latest" "${SERVICEARGS[@]}"
}

docker_stop() {
    local service_name service=$1
    service_name=$(get_service_name "$service")

    if is_container_running "$service"; then
        printf -- 'Stopping container for service %s...' "$service" >&2
        docker stop "$service_name" > /dev/null
        printf -- 'Done\n' >&2
    fi
}

docker_up() {
    local service_name service=$1 net_alias='' \
          env_file volume_map host_map port_map \
          __no_client="$2" cid pid signal exit_code=1

    service_name=$(get_service_name "$service")
    env_file=$(get_env_file "$service")
    volume_map=$(get_volumes_map "$service")
    host_map=$(get_hosts_map "$service")
    port_map=$(get_ports_map "$service")

    if [[ "$DOCKER_NETWORK" != 'bridge' ]]; then
        net_alias="--network-alias=$service "
    fi

    if is_container_running "$service"; then
        [[ "$service" == 'graphql-server-schema' ]] && return 0
        printf -- 'Container for service %s is already running\n' "$service" >&2
        return 1
    fi

    if container_exists "$service"; then
        printf -- "Container for service %s already exist.
Please remove it by running the following and try again.

    $ docker rm %s_1

Alternatively run the command below to remove everything tied to this project.
NB! Beware *all* docker images will be removed as well.
The corresponding image will be rebuilt upon next start of the service (can take several minutes).

    $ ./docker.sh clean --i-am-not-running-this-on-a-server

If you only want to remove all *containers* tied to this project and keep the images, run the following

    $ docker ps -q -a --filter 'name=%s_*' | xargs docker rm > /dev/null

It is recommended to run the latter if this is the first time you're starting this project after
docker-compose has been removed.
" "$service" "$service_name" "$DOCKER_PROJECT" >&2
        return 1
    fi

    if $__no_client; then
        : "${UNIT? "Running without client requires \$UNIT to be set"}"
        # shellcheck disable=2086
        cid=$(docker run --rm --detach $env_file $net_alias $volume_map $host_map $port_map \
        --log-driver=journald --log-opt env=UNIT --env UNIT \
        --network=$DOCKER_NETWORK \
        --name "$service_name" \
        "$service_name:latest" "${SERVICEARGS[@]}")
        pid=$(/usr/bin/docker inspect "$cid" --format "{{ .State.Pid }}")
        for signal in SIGTERM SIGHUP SIGINT SIGUSR1 SIGUSR2 SIGQUIT; do
        # shellcheck disable=SC2064
        trap "exit_code=0; docker kill --signal $signal $cid >/dev/null" $signal
        done
        # Block until the container is no longer running
        while [[ $(docker container inspect -f '{{.State.Running}}' "$cid" 2>/dev/null) = "true" ]]; do
        tail --pid="$pid" -f /dev/null || true
        done
        return $exit_code
    else
        set -x
        # shellcheck disable=2086
        exec docker run --rm $env_file $net_alias $volume_map $host_map $port_map \
        --network=$DOCKER_NETWORK \
        --name "$service_name" \
        "$service_name:latest"
    fi
}

print_env() {
    local env_prefix env_var vars_in_prefix
    for env_prefix in "${DOCKER_ENV_PREFIXES[@]}"; do
        eval 'vars_in_prefix=(${!'"$env_prefix"'@})'
        for env_var in "${vars_in_prefix[@]}"; do
            [[ "$env_var" == 'DOCKER_ENV_PREFIXES' ]] && continue
            printf -- '%s=%s\n' "$env_var" "${!env_var}"
        done
    done
}

is_container_running() {
    local service=$1
    service_name=$(get_service_name "$service")
    docker ps -q --filter 'name='"${service_name}"'' | wc -l | grep -vq 0 && return 0 || return 1
}

container_exists() {
    local service=$1
    service_name=$(get_service_name "$service")
    docker ps -a -q --filter 'name='"${service_name}"'' | wc -l | grep -vq 0 && return 0 || return 1
}

DOCKER_BUILD_CONTEXT_ALL=${DOCKER_BUILD_CONTEXT_ALL:-false}
build_context() {
    $DOCKER_BUILD_CONTEXT_ALL && return 0
    local service_path service=$1

    if [[ $service == "all" ]]; then
        export DOCKER_BUILD_CONTEXT_ALL=true
        for service_path in "$DOCKER_SERVICES_PATH"/*; do
            if [[ -x $service_path/generate-build-context.sh ]]; then
                "$service_path/generate-build-context.sh"
            fi
        done
    else
        service_path="$DOCKER_SERVICES_PATH/$service"
        if [[ -d $service_path ]]; then
             if [[ -x $service_path/generate-build-context.sh ]]; then
                "$service_path/generate-build-context.sh"
            fi
        else
            printf -- 'Service %s not found\n' "$service" >&2
            return 1
        fi
    fi
    return 0
}

load_project_env() {
    if [[ -f $PROJECT_PATH/.env ]]; then
        read_env_file "$PROJECT_PATH/.env"
    fi

    if [[ -n "$DOCKER_HOSTS_MAP" ]]; then
        for ((i=0;i<${#DOCKER_HOSTS_MAP[@]};i+=2)); do
            host_name=${DOCKER_HOSTS_MAP[i]}
            eval "host_ip=${DOCKER_HOSTS_MAP[i+1]}"
            DOCKER_HOSTS_MAP[i+1]=$host_ip
        done
    fi

    if [[ -z "$DOCKER_NETWORK" ]]; then
        printf -- 'Warning: using default network bridge, consider using an isolated bridge for this project.
Run following command for documentation:

$ man docker-network-create

When the network is created set appending the following name in
%s
DOCKER_NETWORK=<docker-network-name>
' "$DOCKER_PROJECT/.env" >&2
        DOCKER_NETWORK=bridge
    fi

    if [[ -z $DOCKER_USER_ID ]]; then
        DOCKER_USER_ID=$(id -u)
        export DOCKER_USER_ID
    fi
}

read_env_file() {
    local raw_env_line env_file_path=$1
    while IFS= read -r raw_env_line; do
        [[ -z $raw_env_line || $raw_env_line = '#'* ]] && continue
        if [[ $raw_env_line =~ DOCKER_* ]]; then
            eval "$raw_env_line"
        else
            eval "export $raw_env_line"
        fi
    done < "$env_file_path"
}

get_service_name() {
    local service_name service=$1
    service_name=${DOCKER_PROJECT}_${service////-}
    printf -- '%q' "$service_name"
}

get_dockerfile_path() {
    local service_path i service=$1
    service_path=$DOCKER_SERVICES_PATH/$service
    if [[ -d "$DOCKER_SERVICES_PATH/$service" ]]; then
        if [[ -f "$service_path/$DOCKER_ENVIRONMENT.Dockerfile" ]]; then
            printf -- '%s/%s' "$service_path" "$DOCKER_ENVIRONMENT.Dockerfile"
            return 0
        elif [[ -f "$service_path/Dockerfile" ]]; then
            printf -- '%s/Dockerfile' "$service_path"
            return 0
        fi
    fi
    return 1
}

get_env_file() {
    local service_path service=$1
    service_path="$DOCKER_SERVICES_PATH/$service"
    if [[ -f "$service_path/$DOCKER_ENVIRONMENT.env.list" ]]; then
        printf -- '--env-file=%q ' "$service_path/$DOCKER_ENVIRONMENT.env.list"
    elif [[ -f "$service_path/env.list" ]]; then
        printf -- '--env-file=%q ' "$service_path/env.list"
    fi
}

get_build_args_map() {
    local service_path service=$1
    service_path="$DOCKER_SERVICES_PATH/$service"
    if [[ -f "$service_path/build-args.list" ]]; then
        read_build_args_list "$service_path/build-args.list"
    fi
    if [[ -f "$service_path/$DOCKER_ENVIRONMENT.build-args.list" ]]; then
        read_build_args_list "$service_path/$DOCKER_ENVIRONMENT.build-args.list"
    fi
}

read_build_args_list() {
    local raw_build_arg_value interpolated_build_arg_value build_args_list_path=$1
    while IFS= read -r raw_build_arg_value; do
        [[ -z "$raw_build_arg_value" || $raw_build_arg_value = '#'* ]] && continue
        eval "interpolated_build_arg_value=$raw_build_arg_value"
        printf -- "--build-arg %q " "$interpolated_build_arg_value"
    done < "$build_args_list_path"
}

get_volumes_map() {
    local service_path service=$1
    service_path="$DOCKER_SERVICES_PATH/$service"
    if [[ -f "$service_path/volumes.list" ]]; then
        read_volumes_list "$service_path/volumes.list"
    fi
    if [[ -f "$service_path/$DOCKER_ENVIRONMENT.volumes.list" ]]; then
        read_volumes_list "$service_path/$DOCKER_ENVIRONMENT.volumes.list"
    fi
}

read_volumes_list() {
    local raw_volume_value interpolated_volume_value volumes_list_path=$1
    while IFS= read -r raw_volume_value; do
        [[ -z "$raw_volume_value" || $raw_volume_value = '#'* ]] && continue
        eval "interpolated_volume_value=$raw_volume_value"
        printf -- "-v %q " "$interpolated_volume_value"
    done < "$volumes_list_path"
}

get_hosts_map() {
    local service_path service=$1
    service_path="$DOCKER_SERVICES_PATH/$service"
    if [[ -f "$service_path/hosts.list" ]]; then
        read_hosts_list "$service_path/hosts.list"
    fi
    if [[ -f "$service_path/$DOCKER_ENVIRONMENT.hosts.list" ]]; then
        read_hosts_list "$service_path/$DOCKER_ENVIRONMENT.hosts.list"
    fi
}

read_hosts_list() {
    local host_name host_ip hosts_list_path=$1
    while IFS= read -r host_name; do
        [[ -z $host_name || $host_name = '#'* ]] && continue
        host_ip=$(get_host_ip "$host_name")

        if [[ -z $host_ip ]]; then
        printf -- 'Unable to find ip for host %s in DOCKER_HOSTS_MAP\n' "$host_name" >&1
        return 1
        fi
        printf -- "--add-host=%q:%q " "$host_name" "$host_ip"
    done < "$hosts_list_path"
}

get_host_ip() {
    local i host_name=$1
    for ((i=0; i<${#DOCKER_HOSTS_MAP[@]}; i+=2)); do
        if [[ "$host_name" == "${DOCKER_HOSTS_MAP[i]}" ]]; then
        printf -- '%s' "${DOCKER_HOSTS_MAP[i+1]}"
        return 0
        fi
    done
    return 1
}

get_ports_map() {
    local service_path service=$1
    service_path="$DOCKER_SERVICES_PATH/$service"
    if [[ -f "$service_path/ports.list" ]]; then
        read_ports_list "$service_path/ports.list"
    fi
    if [[ -f "$service_path/$DOCKER_ENVIRONMENT.ports.list" ]]; then
        read_ports_list "$service_path/$DOCKER_ENVIRONMENT.ports.list"
    fi
}

read_ports_list() {
    local raw_port_value interpolated_port_value ports_list_path=$1
    while IFS= read -r raw_port_value; do
        [[ -z $raw_port_value || $raw_port_value = '#'* ]] && continue
        eval "interpolated_port_value=$raw_port_value"
        printf -- "-p %q " "$interpolated_port_value"
    done < "$ports_list_path"
}

docker_main "$@"
