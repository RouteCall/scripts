#!/usr/bin/env bash

AST='/usr/local/sbin/asterisk'
JOT='/usr/bin/jot'
INTERVAL=1
[[ "$1" =~ ^[0-9]+$ ]] && MAX_CALLS=$1 || exit 1

_get_ast_now() {
  local ast_counts=""
  export active_channels=0
  export active_calls=0
  export calls_processed=0

  ast_counts=$("${AST}" -rx 'core show channels count' | grep -Eo '^[0-9]+')
  active_channels=$(echo "${ast_counts}" | xargs | cut -f1 -d' ')
  active_calls=$(echo "${ast_counts}" | xargs | cut -f2 -d' ')
  calls_processed=$(echo "${ast_counts}" | xargs | cut -f3 -d' ')

}

_main() {
  while true; do
    _get_ast_now
    local active_calls_live=${active_calls}
    while [[ ${active_calls_live} -lt ${MAX_CALLS} ]]; do
      NUM="55$(( ( "${RANDOM}" % 8 ) +1 ))$(( ( "${RANDOM}" % 8 ) +1 ))9$(${JOT} -w%i -r 1 69000000 99999999)"
      ${AST} -rx "channel originate Local/${NUM}@local-calls application wait 100" &> /dev/null &
      active_calls_live=$((active_calls_live+1))
    done
    sleep ${INTERVAL}
  done
}

_main

