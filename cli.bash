#!/usr/bin/env bash

# exit 0 if the script is running interactively
# usage: if isInteractive; then ...; fi
isInteractive() { [ -t 0 ]; }

__setup() {
    local config="$(cliParser \
        :flag:help,-h,--help \
        :flag:verbose,-q,--quiet,invert \
        :flag:useOther,-u,--use-other \
        :val:config,-c,--config \
        :val:format,-f,--format,default=json \
        :pos:input \
        :pos:outfile,default= \
        :done:)"
    logCliConfig "$config"
    parseCliArgs "$config" \
        myInput -hqc /path/to/config myOutput
}

# create a command line parser
# usage: cli :set:[rest] \
# usage:    :flag:<name>,[-char],--string,[invert] \
# usage:    :val:<name>,[-char],--string,[default=[string]] \
# usage:    :pos:<name>
cliParser() {
    local -a args=( "$@" )

    local -A settings=
    local names=()
    local types=()
    local shorts=()
    local longs=()
    local inverts=()
    local defaults=()
    local posArgLookup=()
    local firstDefaultPos=

    local i=
    for ((i=0; i<${#args[@]}; i++)); do
        local arg="${args[$i]}"
        # check for directive
        if ! [[ $arg =~ ^:([a-z]+):(.*) ]]; then
            fatal "invalid directive specification: '$arg' - if you want to finish the directive list, use ':done:'"
        fi
        local directive="${BASH_REMATCH[1]}"
        if [[ "$directive" = 'done' ]]; then
            break
        fi

        local -a options=
        IFS=, read -ra options <<< "${BASH_REMATCH[2]}"
        local option=

        case "$directive" in
            # cli settings
            # :set:[rest]
            set)
                for option in "${options[@]}"; do
                    option="${option##[[:space:]]*}"
                    option="${option%%[[:space:]]*}"
                    if [[ $option = rest ]]; then
                        settings[rest]=1
                    else
                        fatal "invalid 'set' directive option: '$option'"
                    fi
                done
                ;;
            # flag argument
            # :flag:<name>,[-char],--string,[invert]
            flag)
                types[i]=$directive
                for option in "${options[@]}"; do
                    option="${option##[[:space:]]*}"
                    option="${option%%[[:space:]]*}"
                    if [[ -z "${names[$i]}" ]]; then
                        names[i]="${option}"
                    elif [[ $option =~ ^-([a-zA-Z0-9])$ ]]; then
                        shorts[i]="${BASH_REMATCH[1]}"
                    elif [[ $option =~ ^--([a-zA-Z][a-zA-Z0-9-]+)$ ]]; then
                        longs[i]="${BASH_REMATCH[1]}"
                    elif [[ $option = invert ]]; then
                        inverts[i]=1
                        defaults[i]=1
                    else
                        fatal "invalid 'flag' directive option: '$option'"
                    fi
                done
                if [[ -z ${names[$i]} ]]; then fatal "flag directive is missing name as the first option"; fi
                if [[ -z ${longs[$i]} ]]; then fatal "flag directive '${name}' is missing long form flag (e.g. --my-long-flag)"; fi
                ;;
            # value flag argument
            # :val:<name>,[-char],--string,[default=[string]]
            val)
                types[i]=$directive
                for option in "${options[@]}"; do
                    option="${option##[[:space:]]*}"
                    option="${option%%[[:space:]]*}"
                    if [[ -z "${names[$i]}" ]]; then
                        names[i]="${option}"
                    elif [[ $option =~ ^-([a-zA-Z0-9])$ ]]; then
                        shorts[i]="${BASH_REMATCH[1]}"
                    elif [[ $option =~ ^--([a-zA-Z][a-zA-Z0-9-]+)$ ]]; then
                        longs[i]="${BASH_REMATCH[1]}"
                    elif [[ $option =~ ^default=(.*) ]]; then
                        defaults[i]="${BASH_REMATCH[1]}"
                    else
                        fatal "invalid 'flag' directive option: '$option'"
                    fi
                done
                if [[ -z ${names[$i]} ]]; then fatal "flag directive is missing name as the first option"; fi
                if [[ -z ${longs[$i]} ]]; then fatal "flag directive '${name}' is missing long form flag (e.g. --my-long-flag)"; fi
                ;;
            # positional argument
            # :pos:<name>,[default]
            pos)
                types[i]=$directive
                for option in "${options[@]}"; do
                    option="${option##[[:space:]]*}"
                    option="${option%%[[:space:]]*}"
                    if [[ -z "${names[$i]}" ]]; then
                        names[i]="${option}"
                    elif [[ $option =~ ^default=(.*) ]]; then
                        defaults[i]="${BASH_REMATCH[1]}"
                        if [[ -z $firstDefaultPos ]]; then firstDefaultPos=$i; fi
                    else
                        fatal "invalid 'pos' directive option: '$option'"
                    fi
                done
                if [[ -z "${names[$i]}" ]]; then fatal "flag directive is missing name as the first option"; fi
                if [[ ! ${!defaults[*]} =~ (^| )"$i"( |$) ]] && [[ -n $firstDefaultPos ]]; then
                    fatal "all positional arguments after the first default positional argument (#$((firstDefaultPos+1))) must also be default"
                fi
                posArgLookup+=( "${names[$i]}" )
                ;;
            # unknown directive
            *)
                fatal "invalid directive: ':$directive:'"
                ;;
        esac
    done

    declare -p settings names types shorts longs inverts defaults posArgLookup firstDefaultPos | sed 's/^declare /local /'
}

# log the configuration of the command line parser
# usage: logCliConfig <cliConfig>
logCliConfig() {
    eval "$1"
    local format="%-15s %-5s %-5s %-15s %-6s %-7s"$'\n'
    # shellcheck disable=SC2059
    printf -- "$format" name type flag long-flag invert default
    # shellcheck disable=SC2059
    printf -- "$format" ==== ==== ==== ========= ====== =======
    for ((i=0; i<${#names[@]}; i++)); do
        local short=; short="$( [[ -n ${shorts[$i]} ]] && echo "-${shorts[$i]}" || echo '' )"
        local long=; long="$( [[ -n ${longs[$i]} ]] && echo "--${longs[$i]}" || echo '' )"
        local invert=; invert="$( [[ ${types[$i]} = flag ]] && ( [[ -n "${inverts[$i]}" ]] && echo "yes" || echo "no" ) || echo '')"
        local default=; default="$( containsIndex "$i" "${defaults[@]}" && echo "'${defaults[$i]//\'/\\\'}'" || echo '<none>')"
        # shellcheck disable=SC2059
        printf -- "$format" "${names[$i]}" "${types[$i]}" "${short}" "${long}" "${invert}" "${default}"
    done
}

# parse the command line arguments
# usage: parseCliArgs <cliConfig> "$@"
parseCliArgs() {
    local config="$1"
    shift || fatalFuncUsage "${FUNCNAME[0]}"
    local args=( "$@" )
    local flagsDone=
    local posArgsFound=0
    local invalidArgs=()
    local errorStrings=()
    local -A output=
    local restArgs=()
    local arg=

    eval "$config"
    local i=
    for ((i=0; i<${#names[@]}; i++)); do
        output[${names[$i]}]="${defaults[$i]}"
    done

    # trap 'unset -f __addPositionalArg' EXIT
    # set -x
    __addPositionalArg() {
        if (( posArgsFound < ${#posArgLookup} )); then
            output[${posArgLookup[$posArgsFound]}]="$1"
        elif [[ -n "${settings[rest]}" ]]; then
            restArgs+=( "$1" )
        fi
        ((posArgsFound++))
    }

    for ((i=0; i<${#args[@]}; i++)); do
        local arg="${args[i]}"
        if [[ -n $flagsDone ]]; then
            __addPositionalArg "$arg"
        elif [[ $arg == '--' ]]; then
            # check for the explicit end of flags - after this point, all arguments are positional
            flagsDone=1
        elif [[ $arg =~ ^--([^=]+)(=(.*))? ]]; then
            # check for --long-style=flags
            local long="${BASH_REMATCH[1]}"
            local valueProvided; valueProvided=$([[ -n "${BASH_REMATCH[2]}" ]] && echo 1 || echo '')
            local value="${BASH_REMATCH[3]}"
            local index; index=$(findIndex "$long" "${longs[@]}")
            if [[ $index = -1 ]]; then
                invalidArgs+=( "$long" )
                continue
            fi
            local name="${names[$index]}"
            local type="${types[$index]}"
            if [[ $type == "flag" ]]; then
                if [[ -n $valueProvided ]]; then
                    errorStrings+=( "--$long is a boolean flag and cannot be provided an explicit value" )
                    continue
                fi
                output[$name]="$( [[ -n "${inverts[$index]}" ]] && echo '' || echo 1)"
            elif [[ $type == "val" ]]; then
                if [[ -z $valueProvided ]]; then
                    if (( i+1 >= ${#args[@]} )); then
                        errorStrings+=( "--$long is missing its required argument" )
                        continue
                    fi
                    ((i++))
                    value="${args[i]}"
                fi
                output[$name]="$value"
            else
                fatal "flag --$long corresponds to a type of argument that does not support long flags"
            fi
        elif [[ $arg =~ ^-.+ ]]; then
            # check for short style flags (-xzf value -C value)
            for ((j=1; j<${#arg}; j++)); do
                local short="${arg:j:1}"
                local index; index=$(findIndex "$short" "${shorts[@]}")
                if [[ $index = -1 ]]; then
                    invalidArgs+=( "-$short" )
                    continue
                fi
                local name="${names[$index]}"
                local type="${types[$index]}"
                if [[ $type == flag ]]; then
                    output[$name]="$( [[ -n "${inverts[$index]}" ]] && echo '' || echo 1)"
                elif [[ $type == "val" ]]; then
                    if (( j+1 < ${#arg} )) || (( i+1 >= ${#args[@]} )); then
                        errorStrings+=( "-$short is missing its required argument" )
                        continue
                    fi
                    ((i++))
                    output[$name]="${args[i]}"
                fi
            done
        else
            __addPositionalArg "${args[i]}"
        fi
    done

    # assure that we've found all of the required positional arguments
    if [[ -z $firstDefaultPos ]] && (( posArgsFound < ${#posArgLookup[@]} )) ; then
        errorStrings+=( "missing $((${#posArgLookup[@]}-posArgsFound)) positional argument(s):" )
        for ((j=posArgsFound; j<${#posArgLookup[@]}; j++)); do
            local name=${posArgLookup[$j]}
            errorStrings+=( "  $name" )
        done
    elif [[ -n $firstDefaultPos ]] && (( posArgsFound < firstDefaultPos )); then
        errorStrings+=( "missing $((firstDefaultPos-posArgsFound)) positional argument(s):" )
        for ((j=posArgsFound; j<firstDefaultPos; j++)); do
            local name=${posArgLookup[$j]}
            errorStrings+=( "  $name" )
        done
    fi

    # check if there are too many positional arguments, but only if we aren't collecting 'rest' arguments
    if [[ -z "${settings[rest]}" ]] && (( posArgsFound > ${#posArgLookup[@]} )); then
        errorStrings+=( "an additional ((posArgsFound-${#posArgsLookup[@]})) positional argument(s) were found" )
    fi

    # assure that we've found all the required value flags
    for ((i=0; i<${#names[@]}; i++)); do
        if ! containsIndex $i "${defaults[@]}" && ! containsIndex "${names[$i]}" "${output[@]}"; then
            local short=; short="$([[ -n ${shorts[i]} ]] && echo "or -${shorts[i]}" || echo '')"
            errorStrings+=( "missing required value flag: --${longs[$i]} $short" )
        fi
    done
    
    # check for any invalid arguments
    if [[ -n "${invalidArgs[*]}" ]]; then
        errorStrings+=( "invalid argument(s): ${invalidArgs[*]}" )
    fi

    # if there are any errors, print them and exit
    if [[ -n "${errorStrings[*]}" ]]; then
        error "usage: some usage text here..."
        for error in "${errorStrings[@]}"; do
            error "$error"
        done
        exit 1
    fi

    # print the output
    for ((i=0; i<${#output[@]}; i++)); do
        printf "%-20s: %s" "${names[$i]}" "${output[$i]}"$'\n'
    done
}