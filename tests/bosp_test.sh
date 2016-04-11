#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${DIR}/../src/bosp.sh"
declare -A -g parsed_yaml=()

function global_setup() {
  bosp::yaml::parse "./fixtures/test.yml" "parsed_yaml"
}

function yaml::parser::root_children() {
  local root_children=( $(bosp::get_children "parsed_yaml") )
  assertion__array_contains "simple" "${root_children[@]}"
  assertion__array_contains "simple-with-spaces" "${root_children[@]}"
  assertion__array_contains "list" "${root_children[@]}"
  assertion__array_contains "array-list" "${root_children[@]}"
  assertion__array_contains "associative-array" "${root_children[@]}"
  assertion__array_contains "associative-array-nested" "${root_children[@]}"
  assertion__array_contains "parent" "${root_children[@]}"
  assertion__array_contains "newline" "${root_children[@]}"
  assertion__array_contains "newline-folded" "${root_children[@]}"
  assertion__array_contains "comment" "${root_children[@]}"
  assertion__array_contains "object-list" "${root_children[@]}"

  assertion__equal 13 "${#root_children[@]}"
}

function yaml::parser::simple-value() {
  assertion__equal "simple-value" "${parsed_yaml["simple"]}"
  }

function yaml::parser::simple-with-space-value() {
  assertion__equal "simple-with-space-value" "${parsed_yaml["simple-with-spaces"]}"
}

function yaml::parser::newline() {
  newline_test_value=$'Newline\nText with lines'
  assertion__equal "${newline_test_value}" "${parsed_yaml["newline"]}"
}

function yaml::parser::newline-folded() {
  assertion__equal "Newline folded Text with lines" "${parsed_yaml["newline-folded"]}"
}

function yaml::parser::comment() {
  assertion__equal "Comment. Comment line which goes on." "${parsed_yaml["comment"]}"
}

function yaml::parser::parent_children() {
  local parent_children=( $(bosp::get_children "parsed_yaml" "parent") )

  assertion__array_contains "child" "${parent_children[@]}"
  assertion__array_contains "child-with-spaces" "${parent_children[@]}"

  assertion__equal "child-value" "${parsed_yaml["parent:child"]}"
  assertion__equal "child-with-spaces-value" "${parsed_yaml["parent:child-with-spaces"]}"
}

function yaml::parser::list() {
  local list_children=( $(bosp::get_children "parsed_yaml" "list") )

  assertion__array_contains "[0]" "${list_children[@]}"
  assertion__array_contains "[1]" "${list_children[@]}"

  assertion__equal "Element" "${parsed_yaml["list:[0]"]}"
  assertion__equal "Element with spaces" "${parsed_yaml["list:[1]"]}"
}

function yaml::parser::array-list() {
  local array_list_children=( $(bosp::get_children "parsed_yaml" "array-list") )

  assertion__array_contains "[0]" "${array_list_children[@]}"
  assertion__array_contains "[1]" "${array_list_children[@]}"
  assertion__array_contains "[2]" "${array_list_children[@]}"

  assertion__equal "array-element" "${parsed_yaml["array-list:[0]"]}"
  assertion__equal "Array element with spaces" "${parsed_yaml["array-list:[1]"]}"
  assertion__equal "one more" "${parsed_yaml["array-list:[2]"]}"
}

function yaml::parser::array-list-multi-line() {
  local array_list_multi_line_children=( $(bosp::get_children "parsed_yaml" "array-list-multi-line") )

  assertion__array_contains "[0]" "${array_list_multi_line_children[@]}"
  assertion__array_contains "[1]" "${array_list_multi_line_children[@]}"
  assertion__array_contains "[2]" "${array_list_multi_line_children[@]}"

  assertion__equal "array-element-multi-line" "${parsed_yaml["array-list-multi-line:[0]"]}"
  assertion__equal "Array multi line element with spaces" "${parsed_yaml["array-list-multi-line:[1]"]}"
  assertion__equal "one more two" "${parsed_yaml["array-list-multi-line:[2]"]}"
}

function yaml::parser::associative-array() {
  local associative_array_children=( $(bosp::get_children "parsed_yaml" "associative-array") )

  assertion__array_contains "key1" "${associative_array_children[@]}"
  assertion__array_contains "key2" "${associative_array_children[@]}"

  assertion__equal "key1-value" "${parsed_yaml["associative-array:key1"]}"
  assertion__equal "key2-value with space" "${parsed_yaml["associative-array:key2"]}"
}

function yaml::parser::associative-array-multi-line() {
  local associative_array_multi_line_children=( $(bosp::get_children "parsed_yaml" "associative-array-multi-line") )

  assertion__array_contains "key-multi-line-1" "${associative_array_multi_line_children[@]}"
  assertion__array_contains "key-multi-line-2" "${associative_array_multi_line_children[@]}"

  assertion__equal "key-multi-line-1-value" "${parsed_yaml["associative-array-multi-line:key-multi-line-1"]}"
  assertion__equal "key-multi-line-2-value with space" "${parsed_yaml["associative-array-multi-line:key-multi-line-2"]}"
}

function yaml::write() {
  bosp::yaml::write "parsed_yaml"
}