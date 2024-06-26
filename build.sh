#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -v  Deploy version
  -o  Overwrite Magento version
  -p  Log path
  -f  Log file name
  -n  PHP executable (optional)
  -c  Composer script (optional)

Example: ${scriptName} -v 1.0.0 -p /var/www/magento/log/builds
EOF
}

trim()
{
  echo -n "$1" | xargs
}

version=
magentoOverwrite=0
logPath=
logFileName=
phpExecutable=
composerScript=

while getopts hv:op:f:n:c:? option; do
  case "${option}" in
    h) usage; exit 1;;
    v) version=$(trim "$OPTARG");;
    o) magentoOverwrite=1;;
    p) logPath=$(trim "$OPTARG");;
    f) logFileName=$(trim "$OPTARG");;
    n) phpExecutable=$(trim "$OPTARG");;
    c) composerScript=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${logPath}" ]]; then
  # shellcheck disable=SC1090
  source "${currentPath}/log.sh" "-" "-"
else
  if [[ -z "${logFileName}" ]]; then
    # shellcheck disable=SC1090
    source "${currentPath}/log.sh" "${logPath}" "-"
  else
    # shellcheck disable=SC1090
    source "${currentPath}/log.sh" "${logPath}" "${logFileName}"
  fi
fi

if [[ -z "${version}" ]]; then
  echo "No version specified!"
  exit 1
fi

cd "${currentPath}"

if [[ ! -f ${currentPath}/../env.properties ]]; then
  echo "No environment specified!"
  exit 1
fi

buildType=$(ini-parse "${currentPath}/../env.properties" "yes" "build" "type")

if [[ "${buildType}" == "composer" ]]; then
  if [[ "${magentoOverwrite}" == 1 ]]; then
    if [[ -n "${phpExecutable}" ]]; then
      if [[ -n "${composerScript}" ]]; then
        "${currentPath}/build-composer.sh" \
          -v "${version}" \
          -n "${phpExecutable}" \
          -c "${composerScript}" \
          -o
      else
        "${currentPath}/build-composer.sh" \
          -v "${version}" \
          -n "${phpExecutable}" \
          -o
      fi
    else
      if [[ -n "${composerScript}" ]]; then
        "${currentPath}/build-composer.sh" \
          -v "${version}" \
          -c "${composerScript}" \
          -o
      else
        "${currentPath}/build-composer.sh" \
          -v "${version}" \
          -o
      fi
    fi
  else
    if [[ -n "${phpExecutable}" ]]; then
      if [[ -n "${composerScript}" ]]; then
        "${currentPath}/build-composer.sh" \
          -v "${version}" \
          -n "${phpExecutable}" \
          -c "${composerScript}"
      else
        "${currentPath}/build-composer.sh" \
          -v "${version}" \
          -n "${phpExecutable}"
      fi
    else
      if [[ -n "${composerScript}" ]]; then
        "${currentPath}/build-composer.sh" \
          -v "${version}" \
          -c "${composerScript}"
      else
        "${currentPath}/build-composer.sh" \
          -v "${version}"
      fi
    fi
  fi
elif [[ "${buildType}" == "git" ]]; then
  if [[ "${magentoOverwrite}" == 1 ]]; then
    if [[ -n "${phpExecutable}" ]]; then
      if [[ -n "${composerScript}" ]]; then
        "${currentPath}/build-git.sh" \
          -b "${version}" \
          -n "${phpExecutable}" \
          -c "${composerScript}" \
          -o
      else
        "${currentPath}/build-git.sh" \
          -b "${version}" \
          -n "${phpExecutable}" \
          -o
      fi
    else
      if [[ -n "${composerScript}" ]]; then
        "${currentPath}/build-git.sh" \
          -b "${version}" \
          -c "${composerScript}" \
          -o
      else
        "${currentPath}/build-git.sh" \
          -b "${version}" \
          -o
      fi
    fi
  else
    if [[ -n "${phpExecutable}" ]]; then
      if [[ -n "${composerScript}" ]]; then
        "${currentPath}/build-git.sh" \
          -b "${version}" \
          -n "${phpExecutable}" \
          -c "${composerScript}"
      else
        "${currentPath}/build-git.sh" \
          -b "${version}" \
          -n "${phpExecutable}"
      fi
    else
      if [[ -n "${composerScript}" ]]; then
        "${currentPath}/build-git.sh" \
          -b "${version}" \
          -c "${composerScript}"
      else
        "${currentPath}/build-git.sh" \
          -b "${version}"
      fi
    fi
  fi
else
  echo "Invalid build type: ${buildType}"
  exit 1
fi

echo "Finished"
