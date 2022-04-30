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

while getopts hv:op:f:? option; do
  case ${option} in
    h) usage; exit 1;;
    v) version=$(trim "$OPTARG");;
    o) magentoOverwrite=1;;
    p) logPath=$(trim "$OPTARG");;
    f) logFileName=$(trim "$OPTARG");;
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
    "${currentPath}/build-composer.sh" -v "${version}" -o
  else
    "${currentPath}/build-composer.sh" -v "${version}"
  fi
elif [[ "${buildType}" == "git" ]]; then
  "${currentPath}/build-git.sh" -b "${version}"
else
  echo "Invalid build type: ${buildType}"
  exit 1
fi

echo "Finished"