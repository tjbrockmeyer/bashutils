#!/usr/bin/env bash

# find the index of an item in a bash array
# returns -1 if not found
# usage: findIndex <search> <array>
findIndex() {
    local search="$1"
    shift || fatalFuncUsage $FUNCNAME
    findIndex+ "$1" 0 1 "$@"
}

# find the index of an item in a bash array with a starting offset and increment
# returns -1 if not found
# usage: findIndex <offset> <increment> <search-item> <array>
findIndexAdvanced() {
    local offset="$1"
    local increment="$2"
    local search="$3"
    shift 3 || fatalFuncUsage $FUNCNAME
    local array=( "$@" )
    local i
    for (( i=$offset; i<${#array[@]}; i+=increment )); do
        local item="${array[i]}"
        if [[ "$item" = "$search" ]]; then
            echo $i
            return
        fi
    done
    echo -1
}

# check if an array contains an item at the given index
# usage: containsIndex <index> "${<array>[@]}"
containsIndex() {
    local index="$1"
    shift || fatalFuncUsage "${FUNCNAME[0]}"
    local array=( "$@" )
    [[ ${!array[*]} =~ (^| )"$index"( |$) ]]
}
