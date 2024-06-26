#!/bin/bash -e

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -b  Branch to build
  -o  Overwrite Magento version
  -n  PHP executable (optional)
  -c  Composer script (optional)

Example: ${scriptName} -b development
EOF
}

trim()
{
  echo -n "$1" | xargs
}

branch=
magentoOverwrite=0
phpExecutable=
composerScript=

while getopts hb:on:c:? option; do
  case "${option}" in
    h) usage; exit 1;;
    b) branch=$(trim "$OPTARG");;
    o) magentoOverwrite=1;;
    n) phpExecutable=$(trim "$OPTARG");;
    c) composerScript=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${branch}" ]]; then
  echo "No branch specified"
  exit 1
fi

cd "${currentPath}"

if [[ ! -f ${currentPath}/../env.properties ]]; then
  echo "No environment specified!"
  exit 1
fi

magentoVersion=$(ini-parse "${currentPath}/../env.properties" "yes" "install" "magentoVersion")
magentoRepositoryList=( $(ini-parse "${currentPath}/../env.properties" "yes" "install" "repositories") )
buildServer=$(ini-parse "${currentPath}/../env.properties" "yes" "build" "server")
gitUrl=$(ini-parse "${currentPath}/../env.properties" "yes" "build" "gitUrl")
magento=$(ini-parse "${currentPath}/../env.properties" "no" "build" "magento")
composer=$(ini-parse "${currentPath}/../env.properties" "yes" "build" "composer")
serverType=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "type")
webUser=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "webUser")
webGroup=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "webGroup")

if [[ "${magento}" != "no" ]] && [[ "${magento}" != 0 ]]; then
  magento="yes"
fi

if [[ "${composer}" != "yes" ]] && [[ "${composer}" != 1 ]]; then
  composer="no"
fi

if [[ -z "${phpExecutable}" ]]; then
  phpExecutable=$(ini-parse "${currentPath}/../env.properties" "no" "${buildServer}" "php")
fi

if [[ -z "${composerScript}" ]]; then
  composerScript=$(ini-parse "${currentPath}/../env.properties" "no" "${buildServer}" "composer")
fi

if [[ "${serverType}" == "ssh" ]]; then
  echo "--- Building with Git on remote server: ${buildServer} ---"
else
  echo "--- Building with Git on local server: ${buildServer} ---"
  buildPath=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "buildPath")

  magentoRepositories=$( IFS=$','; echo "${magentoRepositoryList[*]}" )

  if [[ "${magento}" == 1 ]] || [[ "${magento}" == "yes" ]]; then
    if [[ "${magentoOverwrite}" == 1 ]]; then
      if [[ -n "${phpExecutable}" ]]; then
        if [[ -n "${composerScript}" ]]; then
          "${currentPath}/build-magento-local.sh" \
            -b "${buildPath}" \
            -m "${magentoVersion}" \
            -r "${magentoRepositories}" \
            -u "${webUser}" \
            -g "${webGroup}" \
            -n "${phpExecutable}" \
            -c "${composerScript}" \
            -o
        else
          "${currentPath}/build-magento-local.sh" \
            -b "${buildPath}" \
            -m "${magentoVersion}" \
            -r "${magentoRepositories}" \
            -u "${webUser}" \
            -g "${webGroup}" \
            -n "${phpExecutable}" \
            -o
        fi
      else
        if [[ -n "${composerScript}" ]]; then
          "${currentPath}/build-magento-local.sh" \
            -b "${buildPath}" \
            -m "${magentoVersion}" \
            -r "${magentoRepositories}" \
            -u "${webUser}" \
            -g "${webGroup}" \
            -c "${composerScript}" \
            -o
        else
          "${currentPath}/build-magento-local.sh" \
            -b "${buildPath}" \
            -m "${magentoVersion}" \
            -r "${magentoRepositories}" \
            -u "${webUser}" \
            -g "${webGroup}" \
            -o
        fi
      fi
    else
      if [[ -n "${phpExecutable}" ]]; then
        if [[ -n "${composerScript}" ]]; then
          "${currentPath}/build-magento-local.sh" \
            -b "${buildPath}" \
            -m "${magentoVersion}" \
            -r "${magentoRepositories}" \
            -u "${webUser}" \
            -g "${webGroup}" \
            -n "${phpExecutable}" \
            -c "${composerScript}"
        else
          "${currentPath}/build-magento-local.sh" \
            -b "${buildPath}" \
            -m "${magentoVersion}" \
            -r "${magentoRepositories}" \
            -u "${webUser}" \
            -g "${webGroup}" \
            -n "${phpExecutable}"
        fi
      else
        if [[ -n "${composerScript}" ]]; then
          "${currentPath}/build-magento-local.sh" \
            -b "${buildPath}" \
            -m "${magentoVersion}" \
            -r "${magentoRepositories}" \
            -u "${webUser}" \
            -g "${webGroup}" \
            -c "${composerScript}"
        else
          "${currentPath}/build-magento-local.sh" \
            -b "${buildPath}" \
            -m "${magentoVersion}" \
            -r "${magentoRepositories}" \
            -u "${webUser}" \
            -g "${webGroup}"
        fi
      fi
    fi
  fi

  if [[ "${magento}" == 1 ]] || [[ "${magento}" == "yes" ]]; then
    if [[ "${composer}" == 1 ]] || [[ "${composer}" == "yes" ]]; then
      composerInstallScript="${currentPath}/../ops/composer-install/web-server.sh"
      if [[ -n "${phpExecutable}" ]]; then
        if [[ -n "${composerScript}" ]]; then
          "${currentPath}/build-git-local.sh" \
            -r "${gitUrl}" \
            -b "${branch}" \
            -i "${magento}" \
            -m "${magentoVersion}" \
            -p "${buildPath}" \
            -u "${webUser}" \
            -g "${webGroup}" \
            -c \
            -s "${composerInstallScript}" \
            -n "${phpExecutable}" \
            -o "${composerScript}"
        else
          "${currentPath}/build-git-local.sh" \
            -r "${gitUrl}" \
            -b "${branch}" \
            -i "${magento}" \
            -m "${magentoVersion}" \
            -p "${buildPath}" \
            -u "${webUser}" \
            -g "${webGroup}" \
            -c \
            -s "${composerInstallScript}" \
            -n "${phpExecutable}"
        fi
      else
        if [[ -n "${composerScript}" ]]; then
          "${currentPath}/build-git-local.sh" \
            -r "${gitUrl}" \
            -b "${branch}" \
            -i "${magento}" \
            -m "${magentoVersion}" \
            -p "${buildPath}" \
            -u "${webUser}" \
            -g "${webGroup}" \
            -c \
            -s "${composerInstallScript}" \
            -o "${composerScript}"
        else
          "${currentPath}/build-git-local.sh" \
            -r "${gitUrl}" \
            -b "${branch}" \
            -i "${magento}" \
            -m "${magentoVersion}" \
            -p "${buildPath}" \
            -u "${webUser}" \
            -g "${webGroup}" \
            -c \
            -s "${composerInstallScript}"
        fi
      fi
    else
      "${currentPath}/build-git-local.sh" \
        -r "${gitUrl}" \
        -b "${branch}" \
        -i "${magento}" \
        -m "${magentoVersion}" \
        -p "${buildPath}" \
        -u "${webUser}" \
        -g "${webGroup}"
    fi
  else
    if [[ "${composer}" == 1 ]] || [[ "${composer}" == "yes" ]]; then
      composerInstallScript="${currentPath}/../ops/composer-install/web-server.sh"
      if [[ -n "${phpExecutable}" ]]; then
        "${currentPath}/build-git-local.sh" \
          -r "${gitUrl}" \
          -b "${branch}" \
          -i "${magento}" \
          -p "${buildPath}" \
          -u "${webUser}" \
          -g "${webGroup}" \
          -c \
          -s "${composerInstallScript}" \
          -n "${phpExecutable}"
      else
        "${currentPath}/build-git-local.sh" \
          -r "${gitUrl}" \
          -b "${branch}" \
          -i "${magento}" \
          -p "${buildPath}" \
          -u "${webUser}" \
          -g "${webGroup}" \
          -c \
          -s "${composerInstallScript}"
      fi
    else
      "${currentPath}/build-git-local.sh" \
        -r "${gitUrl}" \
        -b "${branch}" \
        -i "${magento}" \
        -p "${buildPath}" \
        -u "${webUser}" \
        -g "${webGroup}"
    fi
  fi
fi
