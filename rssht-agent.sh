#!/usr/bin/env bash

trap "trap - SIGINT SIGTERM EXIT; term_rssht; kill -- '-$$'" SIGINT SIGTERM EXIT

NOTIFY_AND_FETCH_TIMEOUT_IN_SECS=60.0
NOTIFY_AND_FETCH_INTERVAL_IN_SECS=5.0
TERM_INTERVAL_IN_SECS=0.5
KILL_AFTER_INTEGER_SECS=2
KILL_INTERVAL_IN_SECS=0.5

SSH_IDENTITY_FILE="$HOME/.ssh/id_rsa"
SSH_USER=myusername
SSH_SERVER=192.168.1.200
SSH_PORT=443

AGENT_ID=$(python - "$SSH_IDENTITY_FILE.pub" <<'EOF'
import sys
import re
print (re.search(r'^\S+ \S+ (.+)$', open(sys.argv[1]).readline()).group(1))
EOF
)

SWAP_DIRECTORY="\$HOME/rssht-swap-dir"
STATUS_FILENAME="$SWAP_DIRECTORY/$AGENT_ID.out"
CMD_FILENAME="$SWAP_DIRECTORY/$AGENT_ID.in"

BIND_IFACE=
DEST_IFACE=localhost

term_rssht() {
    rssht_pid=$!
    start=$(date +%s)
    
    while kill -- "$rssht_pid" 2>/dev/null; do
        sleep "$TERM_INTERVAL_IN_SECS"
        
        now=$(date +%s)
        if [ $(($now - $start)) -ge "$KILL_AFTER_INTEGER_SECS" ]; then
            while kill -KILL "$rssht_pid" 2>/dev/null; do
                sleep "$KILL_INTERVAL_IN_SECS"
            done
            
            break
        fi
    done
}

rssht() {
    bind_port="$1"
    dest_port="$2"
    ssh -o 'ExitOnForwardFailure yes' \
        -R "$BIND_IFACE:$bind_port:$DEST_IFACE:$dest_port" -N -T \
        -i "$SSH_IDENTITY_FILE" $SSH_USER@$SSH_SERVER -p $SSH_PORT &
}

do_cmdline() {
    if [ $# -lt 4 ]; then
        return 1
    fi

    cmd_timestamp="$1"; shift
    controller_id="$1"; shift
    uuid_="$1"; shift
    cmd="$1"; shift

    if [ "$uuid_" = "$prev_uuid" ]; then
        return 0
    fi

    args=""
    term_rssht $args

    case $cmd in
        rssht)
            if [ $# -ge 2 ]; then
                bind_port="$1"; shift
                dest_port="$1"; shift
                args="$bind_port $dest_port"
                rssht $args
            else
                args=""
            fi
            ;;
    esac
    
    prev_uuid="$uuid_"
}

get_status() {
    status_timestamp=$(date +%s)

    if [ -z "${uuid_+x}" ]; then
        echo "$status_timestamp"
        return 0
    fi

    case $cmd in
        rssht)
            status=$(ps -p "$!" >/dev/null 2>&1 && echo -n 0 || echo -n 1)
            ;;
        *)
            status=$(ps -p "$!" >/dev/null 2>&1 && echo -n 1 || echo -n 0)
            ;;
    esac

    echo "$status_timestamp $status $cmd_timestamp $controller_id $uuid_ $cmd $args"
}

notify_status_and_fetch_cmdline() {
    status="$1"
    timeout -s TERM -k 3.0 --preserve-status "$NOTIFY_AND_FETCH_TIMEOUT_IN_SECS" \
        ssh -i "$SSH_IDENTITY_FILE" $SSH_USER@$SSH_SERVER -p $SSH_PORT \
            "echo -e '$status' > "'"'"$STATUS_FILENAME"'"'";" \
            "touch "'"'"$CMD_FILENAME"'"'";" \
            "cat "'"'"$CMD_FILENAME"'"'";"
}

main() {
    prev_uuid=
    
    while true; do
        status=$(get_status)
        cmdline=$(notify_status_and_fetch_cmdline "$status")
        do_cmdline $cmdline
        sleep "$NOTIFY_AND_FETCH_INTERVAL_IN_SECS"
    done
}

main
