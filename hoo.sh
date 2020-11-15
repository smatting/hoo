#!/usr/bin/env bash

set -e

PARENT_PID=$$

# function kill_all() {
#     kill -9 -${PARENT_PID} &> /dev/null
# }

# function list_descendants () {
#     local children
#     children="$(pgrep -P "$1")"
#     for pid in $children
#     do
#         list_descendants "$pid"
#     done
#     echo "$children"
# }

# function kill_gracefully() {
#     kill $(list_descendants "$PARENT_PID") &> /dev/null
# }

function config_template() {
    echo "
port=$1
shell=\"nix-shell --command\" # replace with \"/bin/sh -c\" if you dont use nix
"
}

function get_config() {
    if [ -f ".hoo.conf" ]; then
        source .hoo.conf
        shell=${shell-"sh -c"}
        if [ -z $port ]; then
            echo "please specify \"port=<port>\" in .hoo file"
        fi
    else
        random_port=$(( 1024 + $RANDOM % 48127 ))
        config_template $random_port > ".hoo.conf"
        echo "Created a default .hoo.conf. Adjust to your needs if it doesnt work."
        get_config
    fi
}


function get_server_pid() {
    pid=$(ps -e --format pid,args | grep "[h]oogle.*--port ${port}" | awk '{print $1}')
    if [ -z "$pid" ]; then
        echo "0"
        return
    else
        echo "$pid"
        return
    fi
}

rawurlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9] ) o="${c}" ;;
            * )               printf -v o '%%%02x' "'$c"
        esac
        encoded+="${o}"
    done
    echo "${encoded}"    # You can either set a return variable (FASTER) 
    REPLY="${encoded}"   #+or echo the result (EASIER)... or both... :p
}


function assert_hoogle_server() {
    pid=$(get_server_pid)
    if [[ "$pid" -eq 0 ]]; then
        echo -n "Starting hoogle server..."
        cmd="$shell \"hoogle server --local --port $port\" >/dev/null 2>&1 &"
        eval "$cmd"
        pid="$!"
        disown
        sleep 3 # TOOD: wait for server to come up
        set +e
        echo -n "...done"
    fi
}

get_config
assert_hoogle_server
url="http://127.0.0.1:${port}/?q="$(rawurlencode "$*")
xdg-open "$url"
