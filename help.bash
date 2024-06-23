#!/usr/bin/env bash

# print the usage for a function to stderr and exit 1
# usage: fatalFuncUsage $FUNCNAME
fatalFuncUsage() {
    local name="$1"
    shift || fatalFuncUsage $FUNCNAME
    IFS=$'\n' fatal "improper usage of function '$name':" "$(globalHelp $name)"
}

# create documentation from the comments for each function in the script
# usage: documentFunctions <filepath>
documentGlobals() {
    local file="$1"
    shift || fatalFuncUsage $FUNCNAME
    if [[ ! -f $file ]]; then
        fatal "file does not exist: '$file'"
    fi
    file="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
    local func
    while read -r func; do
        __DOCUMENTATION+=( "$func" "$file" )
    done <<< "$(grep -E '^[a-zA-Z][a-zA-Z0-9_-]*\(\)|^[a-zA-Z][a-zA-Z0-9_]*=' "$file" | sed -E 's/(^[^(=]+)[(=].+$/\1/' | sort)"
}

# print the full help for a global name
# usage: globalHelp <name>
globalHelp() {
    local name="$1"
    shift || fatalFuncUsage $FUNCNAME
    __documentScriptUtils
    local index=; index=$(findIndexAdvanced 0 2 "$name" "${__DOCUMENTATION[@]}")
    if [[ $index = -1 ]]; then
        fatal "cannot find documentation for this global: $name"
    fi
    local file="${__DOCUMENTATION[index+1]}"
    local output=
    while read -r line; do
        if [[ $line =~ ^# ]]; then 
            output+="${line#'# '}"$'\n'
        else
            break
        fi
    done <<< "$(grep -B 10 -E "^${name}[(=]" "$file" | sed '$d' | sed '1!G;h;$!d')"
    local lineNumber=; lineNumber="$(grep -En "^${name}[(=]" "$file" | cut -f1 -d:)"
    local fullHelp=; fullHelp="$(sed '1!G;h;$!d' <<< "$output")"
    local usage=; usage="$(grep -E '^usage: ' <<< "$fullHelp" || echo "?? - usage unavailable")"
    fullHelp="$(grep -Ev '^usage: ' <<< "$fullHelp" || echo "?? - help unavailable")"
    fullHelp="${fullHelp#$'\n'}"
    fullHelp="${fullHelp//^/    }"
    usage="${usage//^usage: /    }"
    log "\
~~ $name ~~
location: $file:$lineNumber
usage:
$usage
description:
$fullHelp
"
}

# print the usage for each documented function
# usage: globals                    # look through the documentation
# usage: globals | grep <search>    # look for a specific function
globals() {
    __documentScriptUtils
    local output=
    for ((i=0; i<${#__DOCUMENTATION[@]}; i+=2)); do
        local name=${__DOCUMENTATION[i]}
        local file="${__DOCUMENTATION[i+1]}"
        local shortFile="$(trimPrefix "$__THIS_DIR/" "$file" | trimSuffix .bash)"
        shortFile="${shortFile#tools/script-utils/}"
        local shortHelp=
        while read -r line; do
            if [[ $line =~ ^# ]]
            then shortHelp="$line"
            else break
            fi
        done <<< "$(grep -B 10 -E "^$name[(=]" "$file" | sed '$d' | sed '1!G;h;$!d')"
        output+="$(printf '%-25s - %-8s: %s' "$name" "$shortFile" "${shortHelp#'# '}")"$'\n'
    done
    log "~~ Documented Global Functions ~~"
    log " * run 'globalHelp <name>' for more information"
    log "$output" | sed '$d' | sed 's/^/    /' | sort
}

# document all functions in the script-utils if it hasn't been done yet
# usage: __documentScriptUtils
__documentScriptUtils() {
    if [[ -n $__SCRIPT_UTILS_DOCUMENTED ]]; then return; fi
    __SCRIPT_UTILS_DOCUMENTED=1
    local scriptExt
    for scriptExt in "$__THIS_DIR"/*.bash; do
        documentGlobals "$scriptExt"
    done
}

# array of documented functions
# structure: (name file)...
__DOCUMENTATION=()
