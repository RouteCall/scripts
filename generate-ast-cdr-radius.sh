#!/bin/bash

###
## Example of cdr asterisk in Radius format
#Acct-Status-Type = Stop
#Asterisk-Src = "2122195786"
#Asterisk-Dst = "99995591953149870"
#Asterisk-Dst-Ctx = "outbound-calls"
#Asterisk-Clid = "Foo" <2122195786>"
#Asterisk-Chan = "SIP/zwtelecom03-00088e65"
#Asterisk-Dst-Chan = "SIP/pkemp-00088e66"
#Asterisk-Last-App = "Dial"
#Asterisk-Last-Data = "SIP/5591953149870@pkemp,,rTt"
#Asterisk-Start-Time = "2018-09-01 20:51:19 -0300"
#Asterisk-Answer-Time = "2018-09-01 20:51:41 -0300"
#Asterisk-End-Time = "2018-09-01 20:53:49 -0300"
#Asterisk-Duration = 150
#Asterisk-Bill-Sec = 128
#Asterisk-Disposition = "ANSWERED"
#Asterisk-AMA-Flags = "DOCUMENTATION"
#Asterisk-Unique-ID = "1535845879.560741"
###

# global variables
BASEDIR="$(dirname "$0")"
LOG="${BASEDIR}/generate-ast-cdr-radius.log"
NULL="/dev/null"

# bins
OPENSSL="$(/usr/bin/which openssl)"
OPENSSL="${OPENSSL:-/usr/bin/openssl}"
RADCLIENT="$(/usr/bin/which radclient)"
RADCLIENT="${RADCLIENT:-/usr/bin/radclient}"
# check of bins
${OPENSSL} version > ${NULL} || exit 1
${RADCLIENT} -v > ${NULL}    || exit 1

# default collections
dcontext_collection='outbound-calls outbound-calls outbound-calls outbound-calls outbound-calls inbound-calls inbound-calls inbound-calls from-exten'
channel_collection='SIP/gwttelecom1 SIP/gwttelecom2 SIP/gwttelecom3 SIP/gwttelecom4 SIP/gwttelecom5'
dstchannel_collection='SIP/mediagateway01 SIP/mediagateway02 SIP/avcorp SIP/gosat SIP/mediagateway7 SIP/mediagateway121 SIP/mediagateway122 SIP/mediagateway123'
disposition_collection=('ANSWERED' 'ANSWERED' 'ANSWERED' 'BUSY' 'BUSY' 'BUSY' 'NO ANSWER' 'NO ANSWER')

_help() {
  cat <<EOF
Usage:
  RADIUS_HOST='radius.routecall.io' RADIUS_KEY='<RADIUS password>' $0 [CPS]

CPS: calls per second
EOF
}

# random hexadecimal
_rand_hex() {
  [[ $1 =~ ^[0-9]+$ ]] && min=$1 || exit 1
  ${OPENSSL} rand -hex 3
}

# random number in range $1-$2
_rand_num() {
  [[ $1 =~ ^[0-9]+$ ]] && min=$1 || exit 1
  [[ $2 =~ ^[0-9]+$ ]] && max=$2 || exit 1
  echo -n $(( RANDOM % (max - min + 1 ) + min  ))
}

# generate the cdr in asterisk format for radclient
_generate_cdr_ast() {
  acct_status_type='Stop'
  # src
  asterisk_src="$(_rand_num 1 9)$(_rand_num 1 9)$(_rand_num 2 5)$(_rand_num 100 999)$(_rand_num 1000 9999)"
  # dst
  asterisk_dst=("$(_rand_num 1 9)$(_rand_num 1 9)$(_rand_num 2 5)$(_rand_num 100 999)$(_rand_num 1000 9999)")
  asterisk_dst=("${asterisk_dst[@]}" "$(_rand_num 1 9)$(_rand_num 1 9)9$(_rand_num 4 9)$(_rand_num 100 999)$(_rand_num 1000 9999)")
  asterisk_dst="${asterisk_dst[$(( ${RANDOM} % ${#asterisk_dst[@]} ))]}"
  # dcontext
  asterisk_dst_ctx=(${dcontext_collection})
  asterisk_dst_ctx="${asterisk_dst_ctx[$(( RANDOM % ${#asterisk_dst_ctx[@]} ))]}"
  # clid
  asterisk_clid="${asterisk_src} <${asterisk_src}>"
  # channel
  asterisk_chan=(${channel_collection})
  asterisk_chan="${asterisk_chan[$(( RANDOM % ${#asterisk_chan[@]} ))]}-$(_rand_hex 8)"
  # dstchannel
  asterisk_dst_chan=(${dstchannel_collection})
  asterisk_dst_chan="${asterisk_dst_chan[$(( RANDOM % ${#asterisk_dst_chan[@]} ))]}-$(_rand_hex 8)"
  # now
  second_now=$(date '+%S' | bc)
  # start
  second_start="$((second_now - ((RANDOM+second_now)%(second_now+1))))"
  second_start="$(printf "%.2d" ${second_start})"
  asterisk_start_time="$(date '+%Y-%m-%d %H:%M:')${second_start} -0300"

  # answer, billsec, disposition
  # disposition
  [[ ${#disposition_collection[@]} -gt 0 ]] && 
    asterisk_disposition=${disposition_collection[$(( RANDOM % ${#disposition_collection[@]} ))]} ||
    asterisk_disposition=${disposition_collection[0]}

  # billsec, duration, answer, end
  case "${asterisk_disposition}" in
    "ANSWERED")
      # random duration
      asterisk_duration="$(((RANDOM%600)))"
      # random billsec (duration > billsec)
      asterisk_bill_sec="$(_rand_num 0 ${asterisk_duration})"
      asterisk_answer="$(printf "%(%Y-%m-%d %H:%M:%S)T" $(( $(printf "%(%s)T") + ${asterisk_bill_sec}))) -0300"
      asterisk_end="$(printf "%(%Y-%m-%d %H:%M:%S)T" $(( $(printf "%(%s)T") + ${asterisk_duration}))) -0300"
    ;;
    *)
      # random duration
      asterisk_duration="$(((RANDOM%30)))"
      # calls is not answered, billsec = 0
      asterisk_bill_sec=0
      # calls is not answered, answer = start of timestamp
      asterisk_answer="1969-12-31 21:00:00 -0300"
      asterisk_end="$(printf "%(%Y-%m-%d %H:%M:%S)T" $(( $(printf "%(%s)T") + ${asterisk_duration}))) -0300"
    ;;
  esac

  # lastapp
  asterisk_last_app='Dial'
  # lastdata
  asterisk_last_data="PJSIP/${asterisk_dst}@${asterisk_dst_chan:0:-7},,rTt"
  # amaflags
  asterisk_ama_flags='DOCUMENTATION'
  # uniqueid
  asterisk_unique_id="$(date +"%s.%4N")"

  # format request for send to radclient
  echo "Acct-Status-Type = ${acct_status_type}, Asterisk-Src = \"${asterisk_src}\", Asterisk-Dst = \"${asterisk_dst}\", Asterisk-Dst-Ctx = \"${asterisk_dst_ctx}\", Asterisk-Clid = \"${asterisk_clid}\", Asterisk-Chan = \"${asterisk_chan}\", Asterisk-Dst-Chan = \"${asterisk_dst_chan}\", Asterisk-Last-App = \"${asterisk_last_app}\", Asterisk-Last-Data = \"${asterisk_last_data}\", Asterisk-Start-Time = \"${asterisk_start_time}\", Asterisk-Answer-Time = \"${asterisk_answer}\", Asterisk-End-Time = \"${asterisk_end}\", Asterisk-Duration = ${asterisk_duration}, Asterisk-Bill-Sec = ${asterisk_bill_sec}, Asterisk-Disposition = \"${asterisk_disposition}\", Asterisk-AMA-Flags = \"${asterisk_ama_flags}\", Asterisk-Unique-ID = \"${asterisk_unique_id}\",  Asterisk-Dst-Chan = \"${asterisk_dst_chan}\""
}

_send_acct() {
  _generate_cdr_ast | 
    ${RADCLIENT} "${RADIUS_HOST}" acct "${RADIUS_KEY}" > "${LOG}" 2>&1 
  return $?
}

try_spawn_threads_per_second() {
  [[ $1 =~ ^[0-9]+$ ]] && requests_per_second=$1 || exit 1

  # sleep for get ${requests_per_second}
  sleep_in_seconds="$(printf "%.6f" $(echo "scale=6; 1/${requests_per_second}" | bc))"

  # infinite loop
  while true; do
    # sub-shell in background
    ( _send_acct > "${LOG}" 2>&1 ) &
    # sleeping to ensure the number of requests per second
    sleep "${sleep_in_seconds}"
  done
}

_main() {
  # infinite loop
  while true; do
    try_spawn_threads_per_second "$1"
  done
}

# if argument is int value and if environment variables is nonzero, then exec the main function
if [[ $1 =~ ^[0-9]+$ ]] && [[ -n "${RADIUS_HOST}" ]] || [[ -n "${RADIUS_KEY}" ]]; then
  _main "$1"
else
  _help
  exit 1
fi

