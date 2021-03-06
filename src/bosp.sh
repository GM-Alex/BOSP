#!/usr/bin/env bash

########################################
# Joins an array and returns the string
# Globals:
#   IFS
# Arguments:
#   string join_char
#   array  join_array
# Returns:
#   string
########################################
bosp::__join() {
  local IFS="${1}"
  shift
  echo "${*}"
}

##############################################
# Checks if the given element is in the array
# Globals:
#  None
# Arguments:
#   string element we are looking for
#   array  list we are looking for the element
# Returns:
#   bool
##############################################
bosp::__array_contains() {
  local element

  for element in "${@:2}"; do
    if [[ "$element" == "$1" ]]; then
      return 0
    fi
  done

  return 1
}

###########################
# Repeats the given string
# Globals:
#  None
# Arguments:
#   string string to repeat
#   int    times to repeat
# Returns:
#   None
###########################
bosp::__string_repeat() {
  if [[ ${2} -gt 0 ]]; then
    eval="echo {1.."$(($2))"}"
    printf "${1}%.0s" $(eval ${eval})
  fi
}

# Default YAML variables
declare __BOSP_YAML_CURRENT_LINE
declare __BOSP_YAML_CURRENT_PATH=()
declare __BOSP_YAML_CURRENT_VALUE
declare __BOSP_YAML_SPACES=()
declare -i __BOSP_YAML_CURRENT_LEVEL=0
declare -A __BOSP_YAML_ARRAY=()

#########################################
# Initialises the default yaml variables
# Globals:
#   __BOSP_YAML_CURRENT_LINE
#   __BOSP_YAML_CURRENT_PATH
#   __BOSP_YAML_CURRENT_VALUE
#   __BOSP_YAML_SPACES
#   __BOSP_YAML_CURRENT_LEVEL
#   __BOSP_YAML_ARRAY
# Arguments:
#   None
# Returns:
#   None
#########################################
bosp::yaml::__init_values() {
  unset __BOSP_YAML_CURRENT_LINE
  __BOSP_YAML_CURRENT_PATH=()
  unset __BOSP_YAML_CURRENT_VALUE
  __BOSP_YAML_SPACES=()
  __BOSP_YAML_CURRENT_LEVEL=0
  __BOSP_YAML_ARRAY=()
}

#######################################################
# Processes the spaces and determine the current level
# Globals:
#   __BOSP_YAML_CURRENT_LEVEL
# Arguments:
#   string no_spaces
# Returns:
#   None
#######################################################
bosp::yaml::__process_spaces() {
  local no_spaces=${1}
  local last_no_spaces=0

  for i in "${__BOSP_YAML_SPACES[@]}"; do
    let last_no_spaces+=${i}
  done

  if [[ ${last_no_spaces} -lt ${no_spaces} ]]; then # next level so add the new spaces
    __BOSP_YAML_SPACES+=( $((no_spaces - last_no_spaces)) )
  elif [[ ${last_no_spaces} -gt ${no_spaces} ]]; then  # higher level so go back until the level matches
    diff=$(( last_no_spaces - no_spaces ))

    while [[ diff -gt 0 ]]; do
      local cur_step=${__BOSP_YAML_SPACES[${#__BOSP_YAML_SPACES[@]}-1]}
      unset __BOSP_YAML_SPACES[${#__BOSP_YAML_SPACES[@]}-1]
      let diff-=${cur_step}
    done
  fi

  __BOSP_YAML_CURRENT_LEVEL="${#__BOSP_YAML_SPACES[@]}"
}

#############################################
# Gets the current key and sets the full key
# Globals:
#   __BOSP_YAML_CURRENT_PATH
#   __BOSP_YAML_CURRENT_LEVEL
#   __BOSP_YAML_FULL_KEY
# Arguments:
#   string key
# Returns:
#   None
#############################################
bosp::yaml::__process_key() {
  local path_length=${#__BOSP_YAML_CURRENT_PATH[@]}
  local go_back=$(( path_length - __BOSP_YAML_CURRENT_LEVEL ))

  while [[ ${go_back} -gt 0 ]] && [[ ${#__BOSP_YAML_CURRENT_PATH[@]} -gt 0 ]]; do
    unset __BOSP_YAML_CURRENT_PATH[${#__BOSP_YAML_CURRENT_PATH[@]}-1]
    let go_back-=1
  done

  local key=${1}

  __BOSP_YAML_CURRENT_PATH+=( ${key} )
  __BOSP_YAML_FULL_KEY=$(bosp::__join ":" "${__BOSP_YAML_CURRENT_PATH[@]}")
}

#############################################
# Adds the array of values to the yaml array
# Globals:
#   __BOSP_YAML_CURRENT_LEVEL
#   __BOSP_YAML_FULL_KEY
# Arguments:
#   string list_values
# Returns:
#   None
#############################################
bosp::yaml::__add_list_values() {
  local list_values=()

  if [[ ${1} =~ ^([\[\{])(.*)([\]\}]),?$ ]]; then
    local braces=0
    local add_line=''
    local full_lines="${BASH_REMATCH[2]}"

    while [[ ${full_lines} != '' ]]; do
      if [[ ${full_lines} =~ ^(.*),[\ ]*([^:]*:[\ ]+[\{\[].*)$ ]]; then
        if [[ ${add_line} == '' ]]; then
          add_line="${BASH_REMATCH[2]}"
        else
          add_line="${BASH_REMATCH[2]}, ${add_line}"
        fi

        full_lines="${BASH_REMATCH[1]}"

        local open_braces="${add_line//[^\{]}"
        local no_open_braces=${#open_braces}
        local close_braces="${add_line//[^\}]}"
        local no_close_braces=${#close_braces}

        if [[ $(( no_open_braces - no_close_braces )) == 0 ]]; then
          if [[ ${add_line} =~ ^(.*)(,[^\}]*)$ ]]; then
            add_line=${BASH_REMATCH[1]}
            full_lines+=${BASH_REMATCH[2]}
          fi

          list_values+=( "${add_line}" )
          add_line=''
        fi
      elif [[ ${full_lines} =~ ^(.*),[\ ]*(.*)$ ]]; then
        list_values+=( "${BASH_REMATCH[2]}" )
        full_lines="${BASH_REMATCH[1]}"
      else
        list_values+=( "${full_lines}" )
        full_lines=''
      fi
    done
  else
    echo "List declaration parsing issue in '${1}' invalid yaml file"
    exit 1
  fi

  let __BOSP_YAML_CURRENT_LEVEL+=1
  local index
  local line=0

  for (( index=${#list_values[@]}-1 ; index >= 0 ; index-- )) ; do #Reverse index order
    if [[ "${list_values[${index}]}" =~ ^([\ ]*)(.*)([\ ]*)$ ]]; then
      local list_value=${BASH_REMATCH[2]%"${BASH_REMATCH[2]##*[![:space:]]}"}
      local key="[${line}]"

      if [[ ${list_value} =~ ^([^:]*):[\ ]*(.*)$ ]]; then
        key="${BASH_REMATCH[1]}"
        list_value="${BASH_REMATCH[2]}"
      fi

      bosp::yaml::__process_key "${key}"

      if [[ ${list_value} =~ ^([\[\{])(.*)([\]\}])$ ]]; then
        bosp::yaml::__add_list_values "${list_value}"
      else
        __BOSP_YAML_ARRAY[${__BOSP_YAML_FULL_KEY}]="${list_value}"
      fi
    fi

    let line+=1
  done

  let __BOSP_YAML_CURRENT_LEVEL-=1
  unset __BOSP_YAML_FULL_KEY
}

##############################
# Processes the given value
# Globals:
#   __BOSP_YAML_CURRENT_VALUE
#   __BOSP_YAML_CURRENT_LINE
#   __BOSP_YAML_FULL_KEY
# Arguments:
#   string value
# Returns:
#   None
##############################
bosp::yaml::__process_value() {
  local value=${1}
  local value_lines=()

  __BOSP_YAML_CURRENT_VALUE=''

  # Read value lines
  if [[ ${value} != '' ]]; then
    value_lines+=( "${value}" )
  fi

  local is_assoc_array=0

  if [[ ${value} =~ ^[\ ]*[^:]*\{[^\}]*$ ]]; then
    is_assoc_array=1
  fi

  while read -r __BOSP_YAML_CURRENT_LINE &&
        [[ ${__BOSP_YAML_CURRENT_LINE} =~ ^[\ ]*[^:]*$ ]] ||
        [[ ${__BOSP_YAML_CURRENT_LINE} =~ ^[\ ]*[^:]*\{.*$ ]] ||
        [[ ${is_assoc_array} == 1 ]]
  do
    local clean_line="${__BOSP_YAML_CURRENT_LINE#"${__BOSP_YAML_CURRENT_LINE%%[![:space:]]*}"}"

    if [[ ${__BOSP_YAML_CURRENT_LINE} =~ ^.*\}[^,]*$ ]]; then
      is_assoc_array=0
    elif [[ ${__BOSP_YAML_CURRENT_LINE} =~ ^.*\{.*$ ]]; then
      is_assoc_array=1
    fi

    value_lines+=( "${clean_line}" )
  done

  if [[ ${#value_lines[@]} == 0 ]]; then
    unset __BOSP_YAML_FULL_KEY
  else
    local first_line=${value_lines[0]}

    case ${first_line} in
      '|'|'>')
        local divider=" "

        if [[ "${first_line}" == "|" ]]; then
          divider=$'\n'
        fi

        value_lines=("${value_lines[@]:1}") #remove first line
        __BOSP_YAML_CURRENT_VALUE=$(bosp::__join "${divider}" "${value_lines[@]}")
        ;;
      *)
        local array_list_regex='^-\ (.*)$'

        if [[ ${first_line} =~ ${array_list_regex} ]]; then
          local value_line
          local list=()

          for value_line in "${value_lines[@]}"; do
            if [[ ${value_line} =~ ${array_list_regex} ]]; then
              list+=( "${BASH_REMATCH[1]}" )
            else
              echo "Array list parsing issue at '${value_line}', invalid yaml file"
              exit 1
            fi
          done

          local collapsed_lines="[ $(bosp::__join "," "${list[@]}") ]"
          bosp::yaml::__add_list_values "${collapsed_lines[@]}"
        elif [[ ${first_line} =~ ^([\[\{])(.*)$ ]]; then
          local collapsed_lines=$(bosp::__join " " "${value_lines[@]}")
          bosp::yaml::__add_list_values "${collapsed_lines[@]}"
        else
          __BOSP_YAML_CURRENT_VALUE=$(bosp::__join " " "${value_lines[@]}")
        fi
      ;;
    esac
  fi
}

##############################################################
# Parses the file and add the result to the destination_array
# Globals:
#   destination_array
# Arguments:
#   string file
#   string destination_array
# Returns:
#   None
##############################################################
bosp::yaml::parse() {
  bosp::yaml::__init_values

  #TODO file with missing empty line as last line makes trouble
  local file=${1}
  local destination_array=${2}
  local current_ifs=${IFS}

  IFS=''

  while [[ -n ${__BOSP_YAML_CURRENT_LINE+1} ]] || read -r __BOSP_YAML_CURRENT_LINE; do
    local current_line=${__BOSP_YAML_CURRENT_LINE}

    if [[ ${__BOSP_YAML_CURRENT_LINE} =~ ^([\ ]*)(.*)$ ]]; then
      local content="${BASH_REMATCH[2]}"

      bosp::yaml::__process_spaces ${#BASH_REMATCH[1]}

      if [[ ${content} =~ ^([^:]*):[\ ]*(.*)$ ]]; then
        bosp::yaml::__process_key "${BASH_REMATCH[1]%"${BASH_REMATCH[1]##*[![:space:]]}"}"
        content=${BASH_REMATCH[2]}
      fi

      bosp::yaml::__process_value "${content}"

      if [[ -n ${__BOSP_YAML_FULL_KEY+1} ]]; then
        __BOSP_YAML_ARRAY[${__BOSP_YAML_FULL_KEY}]="${__BOSP_YAML_CURRENT_VALUE}"
      fi

      if [[ "${current_line}" == "${__BOSP_YAML_CURRENT_LINE}" ]]; then
        unset __BOSP_YAML_CURRENT_LINE
      fi
    fi
  done < ${file}

  IFS=${current_ifs}

  local declare_array="declare -g -A ${destination_array}=()"
  eval "${declare_array}"

  for key in "${!__BOSP_YAML_ARRAY[@]}"; do
    local command="${destination_array}[\${key}]=\${__BOSP_YAML_ARRAY[\${key}]}"
    eval "${command}"
  done
}

#########################################
# Writes the parsed array to an yml file
# Globals:
#   source_array
# Arguments:
#   string file
#   string source_array
#   int    indent (optional)
#   string parent_key (optional)
# Returns:
#   None
#########################################
bosp::yaml::write() {
  local file=${1}
  declare -n yaml=${2}
  local indent=2

  if [[ -n ${3+1} ]]; then
    indent=${3}
  fi

  local parent_key=''
  local children=()

  if [[ -n ${4+1} ]]; then
    children=( $(bosp::get_children "${2}" "${4}") )
    parent_key="${4}:"
  else
    local dir=${file%/*}

    if [[ ! -d ${dir} ]]; then
      mkdir -p ${dir}
    fi

    > ${file}

    children=( $(bosp::get_children "${2}") )
  fi

  local child

  for child in "${children[@]}"; do
    local full_key="${parent_key}${child}"
    local level_string="${full_key//[^:]}"
    local level=${#level_string}
    local value="${yaml[${full_key}]}"

    let level*=${indent}
    spaces=$(bosp::__string_repeat ' ' ${level})
    local line

    if [[ ${child} =~ ^\[[0-9]+\]$ ]]; then
      line="${spaces}- ${value}"
    else
      if [[ ${value} == *$'\n'* ]]; then
        value=$'|\n'${value}
        search=$'\n'

        let level+=${indent}
        next_spaces=$(bosp::__string_repeat ' ' ${level})
        replace=$'\n'${next_spaces}

        value=${value//${search}/${replace}}
      fi

      line="${spaces}${child}: ${value}"
    fi

    echo "${line}" >> ${file}
    bosp::yaml::write "${1}" "${2}" "${indent}" "${full_key}"
  done
}



###################################################################
# Gets the children keys for the given parsed array and parent key
# Globals:
#   source_array
# Arguments:
#   array  source_array
#   string parent_key (optional)
# Returns:
#   None
###################################################################
bosp::get_children() {
  declare -A __BOSP_YAML_ARRAY=()
  local __BOSP_YAML_ARRAY

  declare -A source_array=(); unset source_array #Hack for ide

  declare -n source_array=${1}
  local key

  local command

  for key in "${!source_array[@]}"; do
    __BOSP_YAML_ARRAY[${key}]=${source_array[${key}]}
  done

  local parent_key=""

  if [[ -n ${2+1} ]]; then
    parent_key="${2}:"
  fi

  local regex="^${parent_key}([^:]*)"
  local keys=()

  for key in "${!__BOSP_YAML_ARRAY[@]}"; do
    if [[ ${key} =~ ${regex} ]]; then
      if ! (bosp::__array_contains "${BASH_REMATCH[1]}"  "${keys[@]}"); then
        keys+=( "${BASH_REMATCH[1]}" )
      fi
    fi
  done

  if [[ -n "${keys[@]+1}" ]]; then
    echo "${keys[@]}"
  fi
}