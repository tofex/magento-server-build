#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -v  Deploy version
  -o  Overwrite Magento version

Example: ${scriptName} -v 1.0.0
EOF
}

trim()
{
  echo -n "$1" | xargs
}

version=
magentoOverwrite=0

while getopts hv:o? option; do
  case "${option}" in
    h) usage; exit 1;;
    v) version=$(trim "$OPTARG");;
    o) magentoOverwrite=1;;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${version}" ]]; then
  echo "No version specified!"
  exit 1
fi

currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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
buildMagento=$(ini-parse "${currentPath}/../env.properties" "no" "build" "magento")
serverType=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "type")
webUser=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "webUser")
webGroup=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "webGroup")
phpBinary=$(ini-parse "${currentPath}/../env.properties" "no" "${buildServer}" "php")

if [[ "${buildMagento}" != "no" ]]; then
  buildMagento="yes"
fi

if [[ -z "${phpBinary}" ]]; then
  phpBinary="php"
fi

if [[ "${serverType}" == "ssh" ]]; then
  echo "--- Building with Composer on remote server: ${buildServer} ---"
else
  echo "--- Building with Composer on local server: ${buildServer} ---"
  buildPath=$(ini-parse "${currentPath}/../env.properties" "yes" "${buildServer}" "buildPath")

  magentoRepositories=$( IFS=$','; echo "${magentoRepositoryList[*]}" )

  if [[ "${buildMagento}" == "yes" ]]; then
    if [[ "${magentoOverwrite}" == 1 ]]; then
      "${currentPath}/build-magento-local.sh" \
        -b "${buildPath}" \
        -m "${magentoVersion}" \
        -r "${magentoRepositories}" \
        -u "${webUser}" \
        -g "${webGroup}" \
        -n "${phpBinary}" \
        -o
    else
      "${currentPath}/build-magento-local.sh" \
        -b "${buildPath}" \
        -m "${magentoVersion}" \
        -r "${magentoRepositories}" \
        -u "${webUser}" \
        -g "${webGroup}" \
        -n "${phpBinary}"
    fi
  fi

  repositories=$( IFS=$','; echo "${repositoryList[*]}" )

  if [[ "${#additionalComposerProjectList[@]}" -gt 0 ]]; then
    additionalComposerProjects=$( IFS=$','; echo "${additionalComposerProjectList[*]}" )

    "${currentPath}/build-composer-local.sh" \
      -r "${repositories}" \
      -s "${magentoRepositories}" \
      -p "${composerProject}" \
      -v "${version}" \
      -a "${additionalComposerProjects}" \
      -m "${magentoVersion}" \
      -b "${buildPath}" \
      -u "${webUser}" \
      -g "${webGroup}" \
      -n "${phpBinary}"
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
      -n "${phpBinary}"
  fi
fi
