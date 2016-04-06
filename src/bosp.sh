#!/usr/bin/env bash

declare __BOSP_YAML_CURRENT_PATH=()
declare __BOSP_YAML_CURRENT_LINE
declare __BOSP_YAML_CURRENT_VALUE
declare __BOSP_YAML_CURRENT_VALUE_LINES=()
declare __BOSP_YAML_SPACES=()
declare -i __BOSP_YAML_CURRENT_LEVEL=0
declare -A __BOSP_YAML_ARRAY=()

bosp::join() {
  local IFS="${1}"
  shift
  echo "${*}"
}


bosp::yaml::init_values() {
  unset __BOSP_YAML_CURRENT_LINE
  unset __BOSP_YAML_CURRENT_VALUE

  __BOSP_YAML_CURRENT_PATH=()
  __BOSP_YAML_ARRAY=()
}

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

bosp::yaml::process_value_lines() {
  __BOSP_YAML_CURRENT_VALUE_LINES=()

  while read -r __BOSP_YAML_CURRENT_LINE &&
        [[ ${__BOSP_YAML_CURRENT_LINE} =~ ^([\ ]*)([^:]*)$ ]]
  do
    __BOSP_YAML_CURRENT_VALUE_LINES+=( "${BASH_REMATCH[2]}" )
  done
}

bosp::yaml::add_array_list() {
  let __BOSP_YAML_CURRENT_LEVEL+=1
  local line=0

  for value_line in "${__BOSP_YAML_CURRENT_VALUE_LINES[@]}"; do
    bosp::yaml::process_key "[${line}]"

    if [[ ${value_line} =~ ^([\ ]*)(.*)$ ]]; then
      __BOSP_YAML_ARRAY[${__BOSP_YAML_FULL_KEY}]="${BASH_REMATCH[2]}"
    fi

    let line+=1
  done

  let __BOSP_YAML_CURRENT_LEVEL-=1
  unset __BOSP_YAML_FULL_KEY
}

bosp::yaml::process_value() {
  local value=${1}

  __BOSP_YAML_CURRENT_VALUE=''

  case ${value} in
    '|'|'>')
      bosp::yaml::process_value_lines

      local divider=$'\n'

      if [[ "${value}" == ">" ]]; then
        divider=" "
      fi

      __BOSP_YAML_CURRENT_VALUE=$(bosp::join "${divider}" "${__BOSP_YAML_CURRENT_VALUE_LINES[@]}")
      ;;
    '')
      bosp::yaml::process_value_lines

      local value_lines=${#__BOSP_YAML_CURRENT_VALUE_LINES[@]}

      if [[ ${value_lines} == 0 ]]; then
        unset __BOSP_YAML_FULL_KEY
      elsechecking
        local array_list_regex='^-\ (.*)$'

        if [[ ${__BOSP_YAML_CURRENT_VALUE_LINES[0]} =~ ${array_list_regex} ]]; then
          local value_line
          local temp_value_lines=()

          for value_line in "${__BOSP_YAML_CURRENT_VALUE_LINES[@]}"; do
            if [[ ${value_line} =~ ${array_list_regex} ]]; then
              temp_value_lines+=( "${BASH_REMATCH[1]}" )
            else
              echo "invalid yaml file"
              exit 1
            fi
          done

          __BOSP_YAML_CURRENT_VALUE_LINES=( "${temp_value_lines[@]}" )
          bosp::yaml::add_array_list
        else
          __BOSP_YAML_CURRENT_VALUE=$(bosp::join " " "${__BOSP_YAML_CURRENT_VALUE_LINES[@]}")
        fi
      fi
      ;;
    *)
      if [[ ${value} =~ ^\{.*\}$ ]]; then
        echo "aa"
      elif [[ ${value} =~ ^\[((.*),?)*\]$ ]]; then
        local current_ifs=${IFS}
        IFS=','

        local list
        read -ra list <<< "${BASH_REMATCH[1]}"

        local list_item
        __BOSP_YAML_CURRENT_VALUE_LINES=()

        for list_item in "${list[@]}"; do
          __BOSP_YAML_CURRENT_VALUE_LINES+=( "${list_item}" )
        done

        IFS=${current_ifs}
        bosp::yaml::add_array_list
      else
        __BOSP_YAML_CURRENT_VALUE=${value}
      fi
      ;;
  esac
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
      local spaces="${BASH_REMATCH[1]}"
      local content="${BASH_REMATCH[2]}"

      bosp::yaml::process_spaces ${#spaces}

      if [[ ${content} =~ ^([^:]*):[\ ]*(.*)$ ]]; then
        bosp::yaml::process_key "${BASH_REMATCH[1]%% *}"
        content=${BASH_REMATCH[2]}
      fi

      bosp::yaml::process_value "${content}"

      if [[ -n ${__BOSP_YAML_FULL_KEY+1} ]]; then
        #echo "${__BOSP_YAML_FULL_KEY} | ${__BOSP_YAML_CURRENT_VALUE}"
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