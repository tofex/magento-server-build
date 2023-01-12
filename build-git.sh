#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -b  Branch to build
  -n  PHP executable, default: php

Example: ${scriptName} -b development
EOF
}

trim()
{
  echo -n "$1" | xargs
}

branch=
phpExecutable=

while getopts hb:n:? option; do
  case ${option} in
    h) usage; exit 1;;
    b) branch=$(trim "$OPTARG");;
    n) phpExecutable=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${branch}" ]]; then
  echo "No branch specified"
  exit 1
fi

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "${currentPath}"

if [[ ! -f ${currentPath}/../env.properties ]]; then
  echo "No environment specified!"
  exit 1
fi

buildServer=$(ini-parse "${currentPath}/../env.properties" "yes" "build" "server")
serverType=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "type")
webUser=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "webUser")
webGroup=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "webGroup")

if [[ -z "${phpExecutable}" ]]; then
  phpExecutable=$(ini-parse "${currentPath}/../env.properties" "no" "${buildServer}" "php")
fi

if [[ -z "${phpExecutable}" ]]; then
  phpExecutable="php"
fi

if [[ "${serverType}" == "ssh" ]]; then
  echo "--- Building with Git on remote server: ${buildServer} ---"
else
  echo "--- Building with Git on local server: ${buildServer} ---"
  gitUrl=$(ini-parse "${currentPath}/../env.properties" "yes" "build" "gitUrl")
  buildPath=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "buildPath")
  composer=$(ini-parse "${currentPath}/../env.properties" "yes" "build" "composer")

  if [[ "${composer}" == 1 ]] || [[ "${composer}" == "yes" ]]; then
    composerScript="${currentPath}/../ops/composer-install/web-server.sh"
    "${currentPath}/build-git-local.sh" \
      -r "${gitUrl}" \
      -b "${branch}" \
      -p "${buildPath}" \
      -u "${webUser}" \
      -g "${webGroup}" \
      -c \
      -s "${composerScript}" \
      -n "${phpExecutable}"
  else
    "${currentPath}/build-git-local.sh" \
      -r "${gitUrl}" \
      -b "${branch}" \
      -p "${buildPath}" \
      -u "${webUser}" \
      -g "${webGroup}"
  fi
fi
