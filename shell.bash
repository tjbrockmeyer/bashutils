#!/usr/bin/env bash

# print messages to stdout
# usage: log <message>
log() { printf '%s\n' "$*"; }

# print error messages to stderr
# usage: error <message>
error() { log "$*" >&2; }

# fatal error, print messages and exit with status 1
# usage: fatal <message>
fatal() { error "$@"; exit 1; }

# override for the `source` command that will also document the functions in the file
# usage: source <file>
source() {
    local file
    for file in "$@"; do
        command source "$file"
        documentGlobals "$file"
    done
}

# return a temporary file name with some level of uniqueness
# usage: tmp [prefix]
tmp() {
    local prefix="${1:-tempfile}"
    local tmpDir="${TMPDIR:-/tmp}"
    echo "${tmpDir%/}/inccomp-$prefix-$RANDOM"
}

# cleanup for when a function exits
# usage: finally <command>
finally() {
    local command="$1"
    trap "$command" EXIT
}

# echo all arguments, or if there are none, and there is some stdin, echo that
# usage: argsOrStdin "$@"
argsOrStdin() {
    if [ "$#" -gt 0 ]; then 
        echo "$@"
    elif [ ! -t 0 ]; then 
        cat
    fi
}

# echo all arguments, or if there are none, and there is some stdin, echo that - otherwise, echo the default
# usage: argsOrStdinOrDefault <default-value> "$@"
argsOrStdinOrDefault() {
    local default="$1"
    shift || fatalFuncUsage $FUNCNAME
    if [ "$#" -gt 0 ]; then
        echo "$@"
    elif [ ! -t 0 ]; then
        cat
    else
        echo "$default"
    fi
}
