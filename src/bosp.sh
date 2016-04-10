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
bosp::join() {
  local IFS="${1}"
  shift
  echo "${*}"
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
bosp::yaml::init_values() {
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
bosp::yaml::process_spaces() {
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
bosp::yaml::process_key() {
  local path_length=${#__BOSP_YAML_CURRENT_PATH[@]}
  local go_back=$(( path_length - __BOSP_YAML_CURRENT_LEVEL ))

  while [[ ${go_back} -gt 0 ]] && [[ ${#__BOSP_YAML_CURRENT_PATH[@]} -gt 0 ]]; do
    unset __BOSP_YAML_CURRENT_PATH[${#__BOSP_YAML_CURRENT_PATH[@]}-1]
    let go_back-=1
  done

  local key=${1}

  __BOSP_YAML_CURRENT_PATH+=( ${key} )
  __BOSP_YAML_FULL_KEY=$(bosp::join ":" "${__BOSP_YAML_CURRENT_PATH[@]}")
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
bosp::yaml::add_list_values() {
  declare -n list_values=${1}

  let __BOSP_YAML_CURRENT_LEVEL+=1
  local list_value
  local line=0

  for list_value in "${list_values[@]}"; do
    if [[ ${list_value} =~ ^([\ ]*)(.*)([\ ]*)$ ]]; then
      list_value=${BASH_REMATCH[2]%"${BASH_REMATCH[2]##*[![:space:]]}"}

      if [[ ${list_value} =~ ^(.*):([\ ]*)(.*)$ ]]; then
        bosp::yaml::process_key "${BASH_REMATCH[1]}"
        list_value="${BASH_REMATCH[3]}"
      else
        bosp::yaml::process_key "[${line}]"
      fi

      __BOSP_YAML_ARRAY[${__BOSP_YAML_FULL_KEY}]="${list_value}"
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
bosp::yaml::process_value() {
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

    if [[ ${__BOSP_YAML_CURRENT_LINE} =~ ^.*\}.*$ ]]; then
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
        __BOSP_YAML_CURRENT_VALUE=$(bosp::join "${divider}" "${value_lines[@]}")
        ;;
      *)
        local array_list_regex='^-\ (.*)$'

        if [[ ${first_line} =~ ${array_list_regex} ]]; then
          local value_line
          declare __BOSP_LIST_VALUES=()

          for value_line in "${value_lines[@]}"; do
            if [[ ${value_line} =~ ${array_list_regex} ]]; then
              __BOSP_LIST_VALUES+=( "${BASH_REMATCH[1]}" )
            else
              echo "Array list parsing issue, invalid yaml file"
              exit 1
            fi
          done

          bosp::yaml::add_list_values "__BOSP_LIST_VALUES"
        elif [[ ${first_line} =~ ^([\[\{])(.*)$ ]]; then
          local collapsed_lines=$(bosp::join " " "${value_lines[@]}")

          if [[ ${collapsed_lines} =~ ^([\[\{])(.*)([\]\}])$ ]]; then
            local current_ifs=${IFS}
            IFS=','
            declare __BOSP_LIST_VALUES=()
            read -ra __BOSP_LIST_VALUES <<< "${BASH_REMATCH[2]}"
            IFS=${current_ifs}

            bosp::yaml::add_list_values "__BOSP_LIST_VALUES"
          else
            echo "Array declaration parsing issue, invalid yaml file"
            exit 1
          fi
        else
          __BOSP_YAML_CURRENT_VALUE=$(bosp::join " " "${value_lines[@]}")
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
  bosp::yaml::init_values

  #TODO file with missing empty line as last line makes trouble
  local file=${1}
  local destination_array=${2}
  local current_ifs=${IFS}

  IFS=''

  while [[ -n ${__BOSP_YAML_CURRENT_LINE+1} ]] || read -r __BOSP_YAML_CURRENT_LINE; do
    local current_line=${__BOSP_YAML_CURRENT_LINE}

    if [[ ${__BOSP_YAML_CURRENT_LINE} =~ ^([\ ]*)(.*)$ ]]; then
      local content="${BASH_REMATCH[2]}"

      bosp::yaml::process_spaces ${#BASH_REMATCH[1]}

      if [[ ${content} =~ ^([^:]*):[\ ]*(.*)$ ]]; then
        bosp::yaml::process_key "${BASH_REMATCH[1]%"${BASH_REMATCH[1]##*[![:space:]]}"}"
        content=${BASH_REMATCH[2]}
      fi

      bosp::yaml::process_value "${content}"

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

  local source_array=${1}
  local key

  local source_array_keys
  local source_array_keys_command="source_array_keys=( \"\${!${source_array}[@]}\" )"
  eval "${source_array_keys_command}"

  local command

  for key in "${source_array_keys[@]}"; do
    command="__BOSP_YAML_ARRAY[\${key}]=\${${source_array}[\${key}]}"
    eval "${command}"
  done

  local parent_key=""

  if [[ -n ${2+1} ]]; then
    parent_key="${2}:"
  fi

  local regex="^${parent_key}([^:]*)"
  local keys=()

  for key in "${!__BOSP_YAML_ARRAY[@]}"; do
    if [[ ${key} =~ ${regex} ]]; then
      keys+=( "${BASH_REMATCH[1]}" )
    fi
  done

  if [[ -n "${keys[@]+1}" ]]; then
    echo "${keys[@]}"
  fi
}