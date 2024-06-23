#!/usr/bin/env bash

# remove the prefix from each argument if present
# usage: trimPrefix <prefix> [str]... <<< [str]...
trimPrefix() {
    local prefix="$1"
    shift || fatalFuncUsage $FUNCNAME
    local line
    argsOrStdin "$@" | while read -r line; do
        echo "${line#"$prefix"}"
    done
}

# remove the suffix from each argument if present
# usage: trimSuffix <suffix> [str]... <<< [str]...
trimSuffix() {
    local suffix="$1"
    shift || fatalFuncUsage $FUNCNAME
    local line
    argsOrStdin "$@" | while read -r line; do
        echo "${line%"$suffix"}"
    done
}

setDifference() {
    local a="$1"
    local b="$2"
    shift 2 || fatalFuncUsage $FUNCNAME
    sort <(printf "$a"$'\n'"$b"$'\n'"$b") | uniq -u
}
