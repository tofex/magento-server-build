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
  -n  PHP executable (optional)
  -c  Composer script (optional)

Example: ${scriptName} -v 1.0.0
EOF
}

trim()
{
  echo -n "$1" | xargs
}

version=
magentoOverwrite=0
phpExecutable=
composerScript=

while getopts hv:on:c:? option; do
  case "${option}" in
    h) usage; exit 1;;
    v) version=$(trim "$OPTARG");;
    o) magentoOverwrite=1;;
    n) phpExecutable=$(trim "$OPTARG");;
    c) composerScript=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${version}" ]]; then
  echo "No version specified!"
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
repositoryList=( $(ini-parse "${currentPath}/../env.properties" "yes" "build" "repositories") )
composerProject=$(ini-parse "${currentPath}/../env.properties" "yes" "build" "composerProject")
additionalComposerProjectList=( $(ini-parse "${currentPath}/../env.properties" "no" "build" "additionalComposerProject") )
magento=$(ini-parse "${currentPath}/../env.properties" "no" "build" "magento")
serverType=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "type")
webUser=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "webUser")
webGroup=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "webGroup")

if [[ "${magento}" != "no" ]] && [[ "${magento}" != 0 ]]; then
  magento="yes"
fi

if [[ -z "${phpExecutable}" ]]; then
  phpExecutable=$(ini-parse "${currentPath}/../env.properties" "no" "${buildServer}" "php")
fi

if [[ -z "${composerScript}" ]]; then
  composerScript=$(ini-parse "${currentPath}/../env.properties" "no" "${buildServer}" "composer")
fi

if [[ "${serverType}" == "ssh" ]]; then
  echo "--- Building with Composer on remote server: ${buildServer} ---"
else
  echo "--- Building with Composer on local server: ${buildServer} ---"
  buildPath=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "buildPath")

  magentoRepositories=$( IFS=$','; echo "${magentoRepositoryList[*]}" )

  if [[ "${magento}" == "yes" ]]; then
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

  repositories=$( IFS=$','; echo "${repositoryList[*]}" )

  if [[ "${#additionalComposerProjectList[@]}" -gt 0 ]]; then
    additionalComposerProjects=$( IFS=$','; echo "${additionalComposerProjectList[*]}" )

    if [[ -n "${phpExecutable}" ]]; then
      if [[ -n "${composerScript}" ]]; then
        "${currentPath}/build-composer-local.sh" \
          -r "${repositories}" \
          -s "${magentoRepositories}" \
          -p "${composerProject}" \
          -v "${version}" \
          -m "${magentoVersion}" \
          -b "${buildPath}" \
          -u "${webUser}" \
          -g "${webGroup}" \
          -n "${phpExecutable}" \
          -c "${composerScript}" \
          -a "${additionalComposerProjects}"
      else
        "${currentPath}/build-composer-local.sh" \
          -r "${repositories}" \
          -s "${magentoRepositories}" \
          -p "${composerProject}" \
          -v "${version}" \
          -m "${magentoVersion}" \
          -b "${buildPath}" \
          -u "${webUser}" \
          -g "${webGroup}" \
          -n "${phpExecutable}" \
          -a "${additionalComposerProjects}"
      fi
    else
      if [[ -n "${composerScript}" ]]; then
        "${currentPath}/build-composer-local.sh" \
          -r "${repositories}" \
          -s "${magentoRepositories}" \
          -p "${composerProject}" \
          -v "${version}" \
          -m "${magentoVersion}" \
          -b "${buildPath}" \
          -u "${webUser}" \
          -g "${webGroup}" \
          -c "${composerScript}" \
          -a "${additionalComposerProjects}"
      else
        "${currentPath}/build-composer-local.sh" \
          -r "${repositories}" \
          -s "${magentoRepositories}" \
          -p "${composerProject}" \
          -v "${version}" \
          -m "${magentoVersion}" \
          -b "${buildPath}" \
          -u "${webUser}" \
          -g "${webGroup}" \
          -a "${additionalComposerProjects}"
      fi
    fi
  else
    if [[ -n "${phpExecutable}" ]]; then
      if [[ -n "${composerScript}" ]]; then
        "${currentPath}/build-composer-local.sh" \
          -r "${repositories}" \
          -s "${magentoRepositories}" \
          -p "${composerProject}" \
          -v "${version}" \
          -m "${magentoVersion}" \
          -b "${buildPath}" \
          -u "${webUser}" \
          -g "${webGroup}" \
          -n "${phpExecutable}" \
          -c "${composerScript}"
      else
        "${currentPath}/build-composer-local.sh" \
          -r "${repositories}" \
          -s "${magentoRepositories}" \
          -p "${composerProject}" \
          -v "${version}" \
          -m "${magentoVersion}" \
          -b "${buildPath}" \
          -u "${webUser}" \
          -g "${webGroup}" \
          -n "${phpExecutable}"
      fi
    else
      if [[ -n "${composerScript}" ]]; then
        "${currentPath}/build-composer-local.sh" \
          -r "${repositories}" \
          -s "${magentoRepositories}" \
          -p "${composerProject}" \
          -v "${version}" \
          -m "${magentoVersion}" \
          -b "${buildPath}" \
          -u "${webUser}" \
          -g "${webGroup}" \
          -c "${composerScript}"
      else
        "${currentPath}/build-composer-local.sh" \
          -r "${repositories}" \
          -s "${magentoRepositories}" \
          -p "${composerProject}" \
          -v "${version}" \
          -m "${magentoVersion}" \
          -b "${buildPath}" \
          -u "${webUser}" \
          -g "${webGroup}"
      fi
    fi
  fi
fi
