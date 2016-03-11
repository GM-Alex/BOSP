#!/usr/bin/env bash

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
  local file=${1}
  local destination_array=${2}
  declare -A __YAML_ARRAY=()
  local __YAML_ARRAY

  local current_ifs=${IFS}
  IFS=''
  local line
  local last_nos
  local nos
  local full_key=""
  local last_key=""
  local key
  local value
  local go_back=0
  local steps=()
  local cur_step
  local diff

  while read -r line; do
    if [[ ${line} =~ ^([\ ]*)([^:]*):[\ ]*(.*)$ ]]; then
      nos=${#BASH_REMATCH[1]}
      key=${BASH_REMATCH[2]}
      value=${BASH_REMATCH[3]}

      # Init values
      if [[ -z ${last_nos+1} ]]; then
        last_nos=${nos}
      fi

      # Detect steps
      if [[ ${last_nos} -lt ${nos} ]]; then
        go_back=0
        steps+=( $((nos - last_nos)) )
      elif [[ ${last_nos} -eq ${nos} ]]; then
        go_back=1
      elif [[ ${last_nos} -gt ${nos} ]]; then
        go_back=1
        diff=$((last_nos - nos))

        while [[ diff -gt 0 ]]; do
          cur_step=${steps[${#steps[@]}-1]}
          unset steps[${#steps[@]}-1]
          diff=$(( diff - cur_step ))
          go_back=$((go_back + 1))
        done
      fi

      last_nos=${nos}

      while [[ ${go_back} -gt 0 ]]; do
        if [[ ${last_key} == *":"* ]]; then
          last_key=${last_key%:*}
        else
          last_key=""
        fi

        go_back=$((go_back - 1))
      done

      if [[ "${last_key}" != "" ]]; then
        #__YAML_ARRAY["${last_key}>"]+="${key}:"
        full_key="${last_key}:${key}"
      else
        full_key="${key}"
      fi

      last_key=${full_key}

      #if [[ "${value}" != "" ]]; then
      __YAML_ARRAY[${full_key}]="${value}"
      #fi
    fi
  done < ${file}

  #echo ${__YAML_ARRAY['Runtime:TEST:B']}

  IFS=${current_ifs}
  eval "declare -g -A ${destination_array}=()"

  for key in "${!__YAML_ARRAY[@]}"; do
    eval "${destination_array}[\${key}]=\${__YAML_ARRAY[\${key}]}"
  done
}

#################################################################
# Gets the children keys for the given yaml array and parent key
# Globals:
#   source_array
# Arguments:
#   array  source_array
#   string parent_key (optional)
# Returns:
#   None
#################################################################
bosp::yaml::get_children() {
  declare -A __YAML_ARRAY=()
  local __YAML_ARRAY

  local source_array=${1}
  local key

  local source_array_keys
  eval "source_array_keys=( \"\${!${source_array}[@]}\" )"

  for key in "${source_array_keys[@]}"; do
    eval "__YAML_ARRAY[\${key}]=\${${source_array}[\${key}]}"
  done

  local parent_key=""

  if [[ -n ${2+1} ]]; then
    parent_key="${2}:"
  fi

  local regex="^${parent_key}([^:]*)$"
  local keys=()

  for key in "${!__YAML_ARRAY[@]}"; do
    if [[ ${key} =~ ${regex} ]]; then
      keys+=( "${BASH_REMATCH[1]}" )
    fi
  done

  if [[ -n "${keys[@]+1}" ]]; then
    echo "${keys[@]}"
  fi
}