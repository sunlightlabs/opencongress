#!/bin/bash

function usage () {
    echo "$(basename $(readlink -f $0)) pattern-to-watch script-to-run"
    echo 
    echo "The script receives three arguments:"
    echo "    1: The event type (moved, modified, etc)"
    echo "    2: The src path (for moved, modified events)"
    echo "    3: The dest path (for moved events)"
    exit 1
}

[ "$#" -eq 2 ] || usage

watch_pattern="$1"
watch_dir=$(dirname "$watch_pattern")
script="$2"

$HOME/virt/bin/watchmedo shell-command \
    --wait \
    --command="${script} \${watch_event_type} \${watch_src_path} \${watch_dest_path}" \
    --pattern="${watch_pattern}" \
    --recursive \
    "${watch_dir}"

