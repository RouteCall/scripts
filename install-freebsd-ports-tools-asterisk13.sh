#!/bin/sh

# List to install tools, Asterisk13 and Sipp via ports
PACKAGES="tcpdump iftop htop iperf lsof ngrep sngrep bind-tools wget vim git bash sudo portmaster asterisk13 asterisk-g72x sipp"
DIR_PORTS='/usr/ports'
PKG='/usr/sbin/pkg'
MAKE='/usr/bin/make'

for package in ${PACKAGES}; do
  dir_package="$(echo "${DIR_PORTS}"/*/"${package}" | xargs -n1 | grep -v distfiles)"
  if [ ! -d "${dir_package}" ]; then
    echo "ERROR: ${package}"
    break
  fi

  installed=$(${PKG} info -o "$(${PKG} info -q)" | grep "${package}")
  if [ -n "${installed}" ]; then
    echo "NOTICE: Package is installed: ${package}"
    continue
  fi

  if ${MAKE} -C "${dir_package}" config-recursive && ${MAKE}-C "${dir_package}" install clean; then
    echo "NOTICE: Package installed with successful: ${package}"
  else
    echo "ERROR:  Package install is failed: ${package}"
    break
  fi

done
