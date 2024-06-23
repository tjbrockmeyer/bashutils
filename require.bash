#!/usr/bin/env bash

# intercept calls to a dependency, sending them to a function to check the requirement first
# no extra checks will be made until the dependency is needed
# the interception will be removed after the first call
# a prompt will allow the user to install the dependency if it is not found
# usage: lazyRequire <name> <check-command> <install-command>
lazyRequire() {
    local name="$1"
    local checkIt="$2"
    local installIt="$3"
    shift 3 || fatalFuncUsage "${FUNCNAME[0]}"
    eval "$name() { __checkRequirement \"$name\" \"$checkIt\" \"$installIt\" && unset -f \"$name\" && \"$name\" \"\$@\" ; }"
}

__orig() {
    set +e
    command "$@"
    local status=$?
    set -e
    return $status
}

# checks the requirement and prompts to install it if needed
# usage: checkRequirement <name> <check-command> <install-command> [args]...
__checkRequirement() {
    local name="$1"
    local checkIt="$2"
    local installIt="$3"
    shift 3 || fatalFuncUsage "${FUNCNAME[0]}"
    local prompt
    if __orig $checkIt &>/dev/null; then
        return
    fi
    if ! isInteractive; then
        fatal "$name is required, but not installed"
    fi
    error "this script requires $name - install it now? (y/n)"
    read -r prompt
    if [ "$prompt" != "y" ]; then
        fatal "$name is required, but not installed"
    fi
    __orig $installIt
}
