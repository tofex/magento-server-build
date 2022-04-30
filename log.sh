#!/bin/bash -e

if [[ $(hash ts >/dev/null 2>&1 && echo "yes" || echo "no") == "yes" ]]; then
  logPath="${1}"

  if [[ -z "${logPath}" ]] || [[ "${logPath}" == "-" ]]; then
    exec > >(ts '[%Y-%m-%d %H:%M:%.S %z]')
    exec 2> >(ts '[%Y-%m-%d %H:%M:%.S %z]' >&2)
  else
    echo "Using log path: ${logPath:?}"
    mkdir -p "${logPath}"

    logFileName="${2}"

    if [[ -z "${logFileName}" ]] || [[ "${logFileName}" == "-" ]]; then
      logFileName="$(date +"%Y_%m_%d_%H_%M_%S").log"
    fi

    echo "Using log file: ${logPath:?}/${logFileName}"
    touch "${logPath:?}/${logFileName}"

    exec > >(ts '[%Y-%m-%d %H:%M:%.S %z]' | tee -a "${logPath:?}/${logFileName}")
    exec 2> >(ts '[%Y-%m-%d %H:%M:%.S %z]' | tee -a "${logPath:?}/${logFileName}" >&2)
  fi
fi
