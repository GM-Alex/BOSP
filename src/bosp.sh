#!/usr/bin/env bash

__BOSP_YAML_CURRENT_PATH=()
__BOSP_YAML_CURRENT_LEVEL=0
__BOSP_YAML_CURRENT_LINE=''
__BOSP_YAML_CURRENT_KEY=''
__BOSP_YAML_LAST_KEY=''
__BOSP_YAML_CURRENT_VALUE=''
declare -g __BOSP_YAML_SPACES=()

declare -i __BOSP_YAML_NO_OF_SPACES=0
declare -i __BOSP_YAML_LAST_NO_OF_SPACES

declare -A __BOSP_YAML_ARRAY=()
__CAKE='aaa'

bosp::join() {
  local IFS="$1"
  shift
  echo "$*"
}


bosp::yaml::init_values() {
  __BOSP_YAML_CURRENT_PATH=()
  __BOSP_YAML_CURRENT_LINE=''
  __BOSP_YAML_CURRENT_KEY=''
  __BOSP_YAML_LAST_KEY=''
  __BOSP_YAML_CURRENT_VALUE=''
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

    local cur_step

    while [[ diff -gt 0 ]]; do
      cur_step=${__BOSP_YAML_SPACES[${#__BOSP_YAML_SPACES[@]}-1]}
      unset __BOSP_YAML_SPACES[${#__BOSP_YAML_SPACES[@]}-1]
      let diff-=${cur_step}
    done
  fi

  __BOSP_YAML_CURRENT_LEVEL="${#__BOSP_YAML_SPACES[@]}"
}

bosp::yaml::process_key() {
  local diff

  local no_spaces=${1}
  local last_no_spaces=0

  for i in "${__BOSP_YAML_SPACES[@]}"; do
    let last_no_spaces+=${i}
  done

  local go_back=1 # same level as before so go one step back on the path

  if [[ ${last_no_spaces} -lt ${no_spaces} ]]; then # next level so add the new spaces
    go_back=0
    __BOSP_YAML_SPACES+=( $((no_spaces - last_no_spaces)) )
  elif [[ ${last_no_spaces} -gt ${no_spaces} ]]; then  # higher level so go back until the level matches
    diff=$(( last_no_spaces - no_spaces ))

    local cur_step

    while [[ diff -gt 0 ]]; do
      cur_step=${__BOSP_YAML_SPACES[${#__BOSP_YAML_SPACES[@]}-1]}
      unset __BOSP_YAML_SPACES[${#__BOSP_YAML_SPACES[@]}-1]
      let diff-=${cur_step}
      let go_back+=1
    done
  fi

  while [[ ${go_back} -gt 0 ]] && [[ ${#__BOSP_YAML_CURRENT_PATH} -gt 0 ]]; do
    unset __BOSP_YAML_CURRENT_PATH[${#__BOSP_YAML_CURRENT_PATH[@]}-1]
    go_back=$((go_back - 1))
  done

  local key=${2}

  __BOSP_YAML_CURRENT_PATH+=( ${key} )
  __BOSP_YAML_FULL_KEY=$(bosp::join ':' "${__BOSP_YAML_CURRENT_PATH[@]}")
}

bosp::yaml::process_value() {
  local value=${1}

  case ${value} in
    '|')
      __BOSP_YAML_CURRENT_VALUE=''
      ;;
    '>')
      __BOSP_YAML_CURRENT_VALUE=''
      ;;
    *)
      __BOSP_YAML_CURRENT_VALUE=${value}
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

  while read -r __BOSP_YAML_CURRENT_LINE; do
    if [[ ${__BOSP_YAML_CURRENT_LINE} =~ ^([\ ]*)([^:]*):[\ ]*(.*)$ ]]; then
      #bosp::yaml::process_spaces
      #bosp::yaml::process_key ${#BASH_REMATCH[1]} ${BASH_REMATCH[2]%% *}
      bosp::yaml::process_value ${BASH_REMATCH[3]%% *}

      echo "K: ${BASH_REMATCH[2]%% *}"
      bosp::yaml::process_spaces ${#BASH_REMATCH[1]}
      echo ${__BOSP_YAML_CURRENT_LEVEL}
      #echo "${__BOSP_YAML_FULL_KEY} | ${__BOSP_YAML_CURRENT_VALUE}"

      #__BOSP_YAML_ARRAY[${__BOSP_YAML_FULL_KEY}]="${__BOSP_YAML_CURRENT_VALUE}"
    fi
  done < ${file}

  IFS=${current_ifs}

  local declare_array="declare -g -A ${destination_array}=()"
  eval "${declare_array}"

  local command

  for key in "${!__BOSP_YAML_ARRAY[@]}"; do
    command="${destination_array}[\${key}]=\${__BOSP_YAML_ARRAY[\${key}]}"
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

  local regex="^${parent_key}([^:]*)$"
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