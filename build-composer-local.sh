#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -r  Repositories (format: type|url|user|password,type2|url2|user2|password2)
  -s  Magento repositories (format: type|url|user|password,type2|url2|user2|password2)
  -p  Composer project
  -v  Composer project version
  -i  Use Magento, default: yes
  -m  Magento version
  -a  Additional composer projects
  -b  Base path of builds
  -u  Web user (optional)
  -g  Web group (optional)
  -n  PHP executable, default: php

Example: ${scriptName} -r "composer|https://composer.company.com|12345|12345" -p customer/project -v dev-development -m 2.4.2 -b /var/www/magento/builds
EOF
}

trim()
{
  echo -n "$1" | xargs
}

repositories=
magentoRepositories=
composerProject=
composerVersion=
magento="yes"
magentoVersion=
additionalComposerProjects=
buildPath=
webUser=
webGroup=
phpExecutable=

while getopts hr:s:p:v:i:m:a:b:u:g:n:? option; do
  case "${option}" in
    h) usage; exit 1;;
    r) repositories=$(trim "$OPTARG");;
    s) magentoRepositories=$(trim "$OPTARG");;
    p) composerProject=$(trim "$OPTARG");;
    v) composerVersion=$(trim "$OPTARG");;
    i) magento=$(trim "$OPTARG");;
    m) magentoVersion=$(trim "$OPTARG");;
    a) additionalComposerProjects=$(trim "$OPTARG");;
    b) buildPath=$(trim "$OPTARG");;
    u) webUser=$(trim "$OPTARG");;
    g) webGroup=$(trim "$OPTARG");;
    n) phpExecutable=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${repositories}" ]]; then
  echo "No magento version specified!"
  exit 1
fi

if [[ -z "${composerProject}" ]]; then
  echo "No composer project specified!"
  exit 1
fi

if [[ -z "${composerVersion}" ]]; then
  echo "No composer version specified!"
  exit 1
fi

if [[ "${magento}" != "no" ]] && [[ "${magento}" != 0 ]]; then
  magento="yes"
fi

if [[ "${magento}" == "yes" ]] && [[ -z "${magentoVersion}" ]]; then
  echo "No magento version specified!"
  exit 1
fi

if [[ -z "${buildPath}" ]]; then
  echo "No base path of builds specified!"
  exit 1
fi

currentUser=$(whoami)
if [[ -z "${webUser}" ]]; then
  webUser="${currentUser}"
fi

currentGroup=$(id -g -n)
if [[ -z "${webGroup}" ]]; then
  webGroup="${currentGroup}"
fi

if [[ -z "${phpExecutable}" ]]; then
  phpExecutable="php"
fi

composerBinary=$(which composer)

echo "Removing composer cache for project repository"
cacheName=$(echo "${composerProject}" | sed 's/\//\$/')
rm -rf ~/".cache/composer/files/${composerProject}/"
rm -rf ~/".composer/cache/files/${composerProject}/"
rm -rf ~/".cache/composer/repo/https---composer.tofex.de/provider-${cacheName}.json"
rm -rf ~/".composer/cache/repo/https---composer.tofex.de/provider-${cacheName}.json"

if [[ "${magento}" == "yes" ]]; then
  magentoPath="${buildPath}/magento"
  magentoVersionFile="${magentoPath}/${magentoVersion}.tar.gz"

  if [[ ! -f "${magentoVersionFile}" ]]; then
    echo "Missing Magento version file at: ${magentoVersionFile}"
    exit 1
  fi
fi

versionPath="${buildPath}/${composerVersion}"

if [[ -d "${versionPath}" ]]; then
  echo "Removing previous version path"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "rm -rf ${versionPath}"
  else
    rm -rf "${versionPath}"
  fi
fi

if [[ ! -d "${versionPath}" ]]; then
  echo "Creating version path: ${versionPath}"
  set +e
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    if ! sudo -H -u "${webUser}" bash -c "mkdir -p ${versionPath} 2>/dev/null"; then
      sudo -H -u "${webUser}" bash -c "sudo mkdir -p ${versionPath} 2>/dev/null"
      sudo -H -u "${webUser}" bash -c "sudo chown ${currentUser}:${currentGroup} ${versionPath} 2>/dev/null"
    fi
  else
    if ! mkdir -p "${versionPath}" 2>/dev/null; then
      sudo mkdir -p "${versionPath}" 2>/dev/null
      sudo chown "${currentUser}":"${currentGroup}" "${versionPath}" 2>/dev/null
    fi
  fi
  set -e
fi

if [[ "${magento}" == "yes" ]]; then
  echo "Copying Magento version file from: ${magentoVersionFile} to build path"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "cp ${magentoVersionFile} ${versionPath}"
  else
    cp "${magentoVersionFile}" "${versionPath}"
  fi

  fileName=$(basename "${magentoVersionFile}")

  cd "${versionPath}"

  echo "Extracting Magento version file: ${fileName}"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "tar -xf ${fileName} | cat"
  else
    tar -xf "${fileName}" | cat
  fi

  echo "Removing copied Magento version file: ${fileName}"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "rm -rf ${fileName}"
  else
    rm -rf "${fileName}"
  fi
fi

if [[ -n "${magentoRepositories}" ]]; then
  echo "Adding Magento repositories"
  IFS=',' read -r -a repositoryList <<< "${magentoRepositories}"
  for repository in "${repositoryList[@]}"; do
    repositoryUrl=$(echo "${repository}" | cut -d"|" -f2)
    repositoryComposerUser=$(echo "${repository}" | cut -d"|" -f3)
    repositoryComposerPassword=$(echo "${repository}" | cut -d"|" -f4)
    repositoryHostName=$(echo "${repositoryUrl}" | awk -F[/:] '{print $4}')
    echo "Adding composer access to repository: ${repositoryUrl}"
    if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
      if [[ -n "${repositoryComposerUser}" ]] || [[ -n "${repositoryComposerPassword}" ]]; then
        sudo -H -u "${webUser}" bash -c "${phpExecutable} ${composerBinary} config --no-interaction http-basic.${repositoryHostName} ${repositoryComposerUser} ${repositoryComposerPassword}"
      fi
    else
      if [[ -n "${repositoryComposerUser}" ]] || [[ -n "${repositoryComposerPassword}" ]]; then
        "${phpExecutable}" "${composerBinary}" config --no-interaction "http-basic.${repositoryHostName}" "${repositoryComposerUser}" "${repositoryComposerPassword}"
      fi
    fi
  done
fi

if [[ -n "${repositories}" ]]; then
  echo "Adding vendor composer repositories"
  IFS=',' read -r -a repositoryList <<< "${repositories}"
  for repository in "${repositoryList[@]}"; do
    repositoryType=$(echo "${repository}" | cut -d"|" -f1)
    repositoryUrl=$(echo "${repository}" | cut -d"|" -f2)
    repositoryComposerUser=$(echo "${repository}" | cut -d"|" -f3)
    repositoryComposerPassword=$(echo "${repository}" | cut -d"|" -f4)
    repositoryHostName=$(echo "${repositoryUrl}" | awk -F[/:] '{print $4}')
    repositoryName=$(echo "${repositoryUrl}" | md5sum | cut -f1 -d" ")
    echo "Adding composer repository: ${repositoryUrl}"
    if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
      sudo -H -u "${webUser}" bash -c "${phpExecutable} ${composerBinary} config --no-interaction repositories.${repositoryName} ${repositoryType} ${repositoryUrl}"
      if [[ -n "${repositoryComposerUser}" ]] || [[ -n "${repositoryComposerPassword}" ]]; then
        sudo -H -u "${webUser}" bash -c "${phpExecutable} ${composerBinary} config --no-interaction http-basic.${repositoryHostName} ${repositoryComposerUser} ${repositoryComposerPassword}"
      fi
    else
      "${phpExecutable}" "${composerBinary}" config --no-interaction "repositories.${repositoryName}" "${repositoryType}" "${repositoryUrl}"
      if [[ -n "${repositoryComposerUser}" ]] || [[ -n "${repositoryComposerPassword}" ]]; then
        "${phpExecutable}" "${composerBinary}" config --no-interaction "http-basic.${repositoryHostName}" "${repositoryComposerUser}" "${repositoryComposerPassword}"
      fi
    fi
  done
fi

if [[ ${magentoVersion:0:1} == 1 ]]; then
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "${phpExecutable} ${composerBinary} require --prefer-dist magento/project-community-edition:${magentoVersion}-patch"
    sudo -H -u "${webUser}" bash -c "${phpExecutable} ${composerBinary} require --prefer-dist magento-hackathon/magento-composer-installer:^3.1.0"
  else
    "${phpExecutable}" "${composerBinary}" require --prefer-dist "magento/project-community-edition:${magentoVersion}-patch"
    "${phpExecutable}" "${composerBinary}" require --prefer-dist magento-hackathon/magento-composer-installer:^3.1.0
  fi
fi

echo "Require project composer package: ${composerProject}:${composerVersion}"
if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
  sudo -H -u "${webUser}" bash -c "${phpExecutable} ${composerBinary} require --prefer-dist ${composerProject}:${composerVersion}"
else
  "${phpExecutable}" "${composerBinary}" require --prefer-dist "${composerProject}":"${composerVersion}"
fi

if [[ -n "${additionalComposerProjects}" ]]; then
  echo "Requiring additional composer packages"
  IFS=',' read -r -a additionalComposerProjectList <<< "${additionalComposerProjects}"
  for additionalComposerProject in "${additionalComposerProjectList[@]}"; do
    echo "Require additional composer package: ${additionalComposerProject}"
    if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
      sudo -H -u "${webUser}" bash -c "${phpExecutable} ${composerBinary} require --prefer-dist ${additionalComposerProject}"
    else
      "${phpExecutable}" "${composerBinary}" require --prefer-dist "${additionalComposerProject}"
    fi
  done
fi

#if [[ -n "${composerPatches}" ]]; then
#  echo "Adding composer requirement: cweagans/composer-patches"
#  ${phpExecutable} ${composerBinary} require --prefer-dist cweagans/composer-patches
#  IFS=',' read -r -a composerPatchesList <<< "${composerPatches}"
#  for composerPatch in "${composerPatchesList[@]}"; do
#    moduleName=$(echo "${composerPatch}" | cut -d'=' -f1)
#    patchName=$(echo "${composerPatch}" | cut -d'=' -f2)
#    patchFile=$(echo "${composerPatch}" | cut -d'=' -f3)
#    if [[ -n "${moduleName}" ]] && [[ -n "${patchName}" ]] && [[ -n "${patchFile}" ]]; then
#      echo "Adding patch for module: ${moduleName} with name: ${patchName} and file: ${patchFile}"
#      jq ".extra[\"patches\"][\"${moduleName}\"] = {\"${patchName}\": \"${patchFile}\"}" composer.json | sponge composer.json
#    fi
#  done
#  ${phpExecutable} ${composerBinary} install
#  ${phpExecutable} ${composerBinary} update --lock
#fi

echo "Creating vcs-info.txt"
echo "Version: ${composerVersion}" > vcs-info.txt
echo "Build-Date: $(LC_ALL=en_US.utf8 date +"%Y-%m-%d %H:%M:%S %z")" >> vcs-info.txt

versionFile="${versionPath}.tar.gz"

if [[ -f "${versionFile}" ]]; then
  echo "Removing previous version file at: ${versionFile}"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "rm -rf ${versionFile}"
  else
    rm -rf "${versionFile}"
  fi
fi

echo "Creating version file at: ${versionFile}"
if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
  sudo -H -u "${webUser}" bash -c "tar -zcf ${versionFile} ."
else
  tar -zcf "${versionFile}" .
fi

cd ..

echo "Removing version path: ${versionPath}"
if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
  sudo -H -u "${webUser}" bash -c "rm -rf ${versionPath}"
else
  rm -rf "${versionPath}"
fi
