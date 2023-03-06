#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -b  Base path of builds
  -m  Magento version
  -r  Magento repositories (format: type|url|user|password,type2|url2|user2|password2)
  -u  Web user (optional)
  -g  Web group (optional)
  -o  Overwrite Magento version
  -n  PHP executable, default: php
  -c  Composer script (optional)

Example: ${scriptName} -b /var/www/magento/builds -m 2.4.2 -r "composer|https://composer.company.com|12345|12345"
EOF
}

trim()
{
  echo -n "$1" | xargs
}

buildPath=
magentoVersion=
magentoRepositories=
webUser=
webGroup=
magentoOverwrite=0
phpExecutable=
composerScript=

while getopts hb:m:r:u:g:on:c:? option; do
  case "${option}" in
    h) usage; exit 1;;
    b) buildPath=$(trim "$OPTARG");;
    m) magentoVersion=$(trim "$OPTARG");;
    r) magentoRepositories=$(trim "$OPTARG");;
    u) webUser=$(trim "$OPTARG");;
    g) webGroup=$(trim "$OPTARG");;
    o) magentoOverwrite=1;;
    n) phpExecutable=$(trim "$OPTARG");;
    c) composerScript=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${buildPath}" ]]; then
  echo "No base path of builds specified!"
  exit 1
fi

if [[ -z "${magentoVersion}" ]]; then
  echo "No magento version specified!"
  exit 1
fi

currentUser="$(whoami)"
if [[ -z "${webUser}" ]]; then
  webUser="${currentUser}"
fi

if [[ $(which id >/dev/null 2>&1 && echo "yes" || echo "no") == "yes" ]]; then
  currentGroup="$(id -g -n)"
else
  currentGroupId=$(grep "${currentUser}:" /etc/passwd | cut -d':' -f4)
  currentGroup=$(grep ":${currentGroupId}:" /etc/group | cut -d':' -f1)
fi
if [[ -z "${webGroup}" ]]; then
  webGroup="${currentGroup}"
fi

if [[ -z "${phpExecutable}" ]]; then
  phpExecutable="php"
fi

composerBinary=$(which composer)

if [[ ! -d "${buildPath}" ]]; then
  echo "Creating base build path: ${buildPath}"
  set +e
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    if ! sudo -H -u "${webUser}" bash -c "mkdir -p ${buildPath} 2>/dev/null"; then
      sudo -H -u "${webUser}" bash -c "sudo mkdir -p ${buildPath} 2>/dev/null"
      sudo -H -u "${webUser}" bash -c "sudo chown ${currentUser}:${currentGroup} ${buildPath} 2>/dev/null"
    fi
  else
    if ! mkdir -p "${buildPath}" 2>/dev/null; then
      sudo mkdir -p "${buildPath}" 2>/dev/null
      sudo chown "${currentUser}":"${currentGroup}" "${buildPath}" 2>/dev/null
    fi
  fi
  set -e
fi

magentoPath="${buildPath}/magento"
magentoVersionPath="${magentoPath}/${magentoVersion}"
magentoVersionFile="${magentoPath}/${magentoVersion}.tar.gz"

if [[ ! -f "${magentoVersionFile}" ]] || [[ "${magentoOverwrite}" == 1 ]]; then
  if [[ -f "${magentoVersionFile}" ]]; then
    echo "Removing composer cache for Magento"
    rm -rf ~/.cache/composer/files/magento/project-community-edition/
    rm -rf ~/.composer/cache/files/magento/project-community-edition/
    rm -rf ~/.cache/composer/repo/https---composer.tofex.de/provider-magento\$project-community-edition.json
    rm -rf ~/.composer/cache/repo/https---composer.tofex.de/provider-magento\$project-community-edition.json
    rm -rf ~/.cache/composer/files/magento/project-enterprise-edition/
    rm -rf ~/.composer/cache/files/magento/project-enterprise-edition/
    rm -rf ~/.cache/composer/repo/https---composer.tofex.de/provider-magento\$project-enterprise-edition.json
    rm -rf ~/.composer/cache/repo/https---composer.tofex.de/provider-magento\$project-enterprise-edition.json
  fi

  if [[ -d "${magentoVersionPath}" ]]; then
    echo "Removing previous Magento path"
    rm -rf "${magentoVersionPath}"
  fi

  echo "Creating Magento path at: ${magentoVersionPath}"
  mkdir -p "${magentoVersionPath}"

  cd "${magentoVersionPath}"

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
          if [[ -n "${composerScript}" ]]; then
            sudo -H -u "${webUser}" bash -c "COMPOSER_MEMORY_LIMIT=-1 ${composerScript} config --ansi --global --no-interaction http-basic.${repositoryHostName} ${repositoryComposerUser} ${repositoryComposerPassword}"
          else
            sudo -H -u "${webUser}" bash -c "${phpExecutable} ${composerBinary} config --ansi --global --no-interaction http-basic.${repositoryHostName} ${repositoryComposerUser} ${repositoryComposerPassword}"
          fi
        fi
      else
        if [[ -n "${repositoryComposerUser}" ]] || [[ -n "${repositoryComposerPassword}" ]]; then
          if [[ -n "${composerScript}" ]]; then
            COMPOSER_MEMORY_LIMIT=-1 "${composerScript}" config --ansi --global --no-interaction "http-basic.${repositoryHostName}" "${repositoryComposerUser}" "${repositoryComposerPassword}"
          else
            "${phpExecutable}" "${composerBinary}" config --ansi --global --no-interaction "http-basic.${repositoryHostName}" "${repositoryComposerUser}" "${repositoryComposerPassword}"
          fi
        fi
      fi
    done
  fi

  if [[ ${magentoVersion:0:1} == 1 ]]; then
    echo "Building Magento 1 composer file"
    echo "{}" > composer.json
    jq '.extra["magento-root-dir"] = "."' composer.json | sponge composer.json
    jq '.extra["magento-deploystrategy"] = "copy"' composer.json | sponge composer.json
    jq '.extra["magento-deploystrategy-dev"] = "copy"' composer.json | sponge composer.json
    jq '.extra["with-bootstrap-patch"] = false' composer.json | sponge composer.json
    jq '.extra["skip-suggest-repositories"] = true' composer.json | sponge composer.json
    jq '.extra["magento-force"] = true' composer.json | sponge composer.json
    jq '.scripts["post-install-cmd"] = ["bash -c \"shopt -s dotglob; test ! -e mage && cp -n -r vendor/magento/project-community-edition/* . || cat\""]' composer.json | sponge composer.json
    jq '.scripts["post-update-cmd"] = ["bash -c \"shopt -s dotglob; test ! -e mage && cp -n -r vendor/magento/project-community-edition/* . || cat\""]' composer.json | sponge composer.json
  else
    if [[ -n "${composerScript}" ]]; then
      COMPOSER_MEMORY_LIMIT=-1 "${composerScript}" create-project --ansi --repository-url=https://repo.magento.com/ "magento/project-community-edition=${magentoVersion}" --no-interaction --prefer-dist .
    else
      "${phpExecutable}" "${composerBinary}" create-project --ansi --repository-url=https://repo.magento.com/ "magento/project-community-edition=${magentoVersion}" --no-interaction --prefer-dist .
    fi
  fi

  if [[ -f "${magentoVersionFile}" ]]; then
    echo "Removing previous Magento version file at: ${magentoVersionFile}"
    if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
      sudo -H -u "${webUser}" bash -c "rm -rf ${magentoVersionFile}"
    else
      rm -rf "${magentoVersionFile}"
    fi
  fi

  echo "Creating Magento version file at: ${magentoVersionFile}"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "tar -zcf ${magentoVersionFile} ."
  else
    tar -zcf "${magentoVersionFile}" .
  fi

  cd ..

  echo "Removing Magento path: ${magentoVersionPath}"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "rm -rf ${magentoVersionPath}"
  else
    rm -rf "${magentoVersionPath}"
  fi
else
  echo "Using Magento version file from: ${magentoVersionFile}"
fi
