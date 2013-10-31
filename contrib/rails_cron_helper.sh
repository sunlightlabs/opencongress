#!/bin/bash

function die () {
    while [ "$#" -gt -0 ]; do
        echo "$1"
        shift
    done
    exit 1
}

cmd=$(basename $(readlink -f "$0"))

[ "$#" -ge 3 ] || die "Usage: $cmd <environment> <src directory> <cmd>"

# Taken from: https://rvm.io/workflow/scripting
# Load RVM into a shell session *as a function*
if [[ -s "$HOME/.rvm/scripts/rvm" ]] ; then
    # First try to load from a user install
    source "$HOME/.rvm/scripts/rvm"
elif [[ -s "/usr/local/rvm/scripts/rvm" ]] ; then
    # Then try to load from a root install
    source "/usr/local/rvm/scripts/rvm"
else
    printf "ERROR: An RVM installation was not found.\n"
    exit 1
fi

export RAILS_ENV=$1; shift
src_dir="$1"; shift
cd "$src_dir" || die "Unable to find $src_dir"
"$@"

