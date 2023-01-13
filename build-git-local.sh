#!/bin/bash -e

scriptName="${0##*/}"

usage()
{
cat >&2 << EOF
usage: ${scriptName} options

OPTIONS:
  -h  Show this message
  -r  Git Repository Url
  -b  Branch to build
  -i  Use Magento, default: yes
  -m  Magento version
  -p  Base path of builds
  -u  Web user (optional)
  -g  Web group (optional)
  -c  Run composer (optional)
  -s  Full path to composer script to run if composer process
  -n  PHP executable, default: php

Example: ${scriptName} -r git@bitbucket.org:project01.git -b development  -p /var/www/magento/builds
EOF
}

trim()
{
  echo -n "$1" | xargs
}

url=
branch=
magento="yes"
magentoVersion=
buildPath=
webUser=
webGroup=
composer=0
composerScript=
phpExecutable=

while getopts hb:r:p:u:g:cs:n:? option; do
  case ${option} in
    h) usage; exit 1;;
    r) url=$(trim "$OPTARG");;
    b) branch=$(trim "$OPTARG");;
    i) magento=$(trim "$OPTARG");;
    m) magentoVersion=$(trim "$OPTARG");;
    p) buildPath=$(trim "$OPTARG");;
    u) webUser=$(trim "$OPTARG");;
    g) webGroup=$(trim "$OPTARG");;
    c) composer=1;;
    s) composerScript=$(trim "$OPTARG");;
    n) phpExecutable=$(trim "$OPTARG");;
    ?) usage; exit 1;;
  esac
done

if [[ -z "${branch}" ]]; then
  echo "No branch specified!"
  exit 1
fi

if [[ -z "${url}" ]]; then
  echo "No repository url specified!"
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

if [[ "${composer}" == 1 ]] && [[ -z "${composerScript}" ]]; then
  echo "No composer script specified"
  exit 1
fi

if [[ -z "${phpExecutable}" ]]; then
  phpExecutable="php"
fi

branchPathName=$(echo "${branch}" | sed 's/[^a-zA-Z0-9\.\-]/_/g')

currentUser=$(whoami)
if [[ -z "${webUser}" ]]; then
  webUser="${currentUser}"
fi

currentGroup=$(id -g -n)
if [[ -z "${webGroup}" ]]; then
  webGroup="${currentGroup}"
fi

webUserHome=$(grep "${webUser}" /etc/passwd | cut -d':' -f6)

echo "Checking SSH keys of repository"
if [[ ! -f "${webUserHome}/.ssh/known_hosts" ]]; then
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "touch ${webUserHome}/.ssh/known_hosts"
  else
    touch "${webUserHome}/.ssh/known_hosts"
  fi
fi

key=$(ssh-keyscan bitbucket.org 2>/dev/null)
if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
  if [[ $(sudo -H -u "${webUser}" bash -c "grep ${key} ${webUserHome}/.ssh/known_hosts" | wc -l) -eq 0 ]]; then
    echo "Adding known host: bitbucket.org"
    sudo -H -u "${webUser}" bash -c "echo ${key} >> ${webUserHome}/.ssh/known_hosts"
  fi
else
  if [[ $(grep "${key}" "${webUserHome}/.ssh/known_hosts" | wc -l) -eq 0 ]]; then
    echo "Adding known host: bitbucket.org"
    echo "${key}" >> "${webUserHome}/.ssh/known_hosts"
  fi
fi

key=$(ssh-keyscan 18.205.93.0 2>/dev/null)
if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
  if [[ $(sudo -H -u "${webUser}" bash -c "grep ${key} ${webUserHome}/.ssh/known_hosts" | wc -l) -eq 0 ]]; then
    echo "Adding known host: 18.205.93.0"
    sudo -H -u "${webUser}" bash -c "echo ${key} >> ${webUserHome}/.ssh/known_hosts"
  fi
else
  if [[ $(grep "${key}" "${webUserHome}/.ssh/known_hosts" | wc -l) -eq 0 ]]; then
    echo "Adding known host: 18.205.93.0"
    echo "${key}" >> "${webUserHome}/.ssh/known_hosts"
  fi
fi

key=$(ssh-keyscan 18.205.93.1 2>/dev/null)
if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
  if [[ $(sudo -H -u "${webUser}" bash -c "grep ${key} ${webUserHome}/.ssh/known_hosts" | wc -l) -eq 0 ]]; then
    echo "Adding known host: 18.205.93.1"
    sudo -H -u "${webUser}" bash -c "echo ${key} >> ${webUserHome}/.ssh/known_hosts"
  fi
else
  if [[ $(grep "${key}" "${webUserHome}/.ssh/known_hosts" | wc -l) -eq 0 ]]; then
    echo "Adding known host: 18.205.93.1"
    echo "${key}" >> "${webUserHome}/.ssh/known_hosts"
  fi
fi

key=$(ssh-keyscan 18.205.93.2 2>/dev/null)
if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
  if [[ $(sudo -H -u "${webUser}" bash -c "grep ${key} ${webUserHome}/.ssh/known_hosts" | wc -l) -eq 0 ]]; then
    echo "Adding known host: 18.205.93.2"
    sudo -H -u "${webUser}" bash -c "echo ${key} >> ${webUserHome}/.ssh/known_hosts"
  fi
else
  if [[ $(grep "${key}" "${webUserHome}/.ssh/known_hosts" | wc -l) -eq 0 ]]; then
    echo "Adding known host: 18.205.93.2"
    echo "${key}" >> "${webUserHome}/.ssh/known_hosts"
  fi
fi

if [[ "${magento}" == "yes" ]]; then
  magentoPath="${buildPath}/magento"
  magentoVersionFile="${magentoPath}/${magentoVersion}.tar.gz"

  if [[ ! -f "${magentoVersionFile}" ]]; then
    echo "Missing Magento version file at: ${magentoVersionFile}"
    exit 1
  fi
fi

isBranch=0
isTag=0

echo "Checking if branch or tag exists: ${branch}"
if [[ $(git ls-remote --heads "${url}" "${branch}" | wc -l) -eq 0 ]]; then
  echo "Branch ${branch} does not exist in repository: ${url}"
  if [[ $(git ls-remote --tags "${url}" "${branch}" | wc -l) -eq 0 ]]; then
    echo "Tag ${branch} does not exist in repository: ${url}"
    exit 1
  else
    echo "Tag ${branch} exists in repository: ${url}"
    isTag=1
  fi
else
  echo "Branch ${branch} exists in repository: ${url}"
  isBranch=1
fi

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

branchGitPath="${buildPath}/git/${branchPathName}"

if [[ -d "${branchGitPath}" ]]; then
  echo "Removing previous build GIT path: ${branchGitPath}"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "rm -rf ${branchGitPath}/"
  else
    rm -rf "${branchGitPath:?}/"
  fi
fi

echo "Creating branch build GIT path: ${branchGitPath}"
if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
  sudo -H -u "${webUser}" bash -c "mkdir -p ${branchGitPath}"
else
  mkdir -p "${branchGitPath}"
fi

cd "${branchGitPath}"

echo "Cloning repository into path: ${branchGitPath}"
if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
  sudo -H -u "${webUser}" bash -c "git clone ${url} ."
else
  git clone "${url}" .
fi

currentBranch=$(git rev-parse --abbrev-ref HEAD)

if [[ "${currentBranch}" == "${branch}" ]]; then
  echo "Already checked out branch: ${branch}"
else
  if [[ "${isBranch}" == 1 ]]; then
    echo "Checking out branch: ${branch}"
    if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
      sudo -H -u "${webUser}" bash -c "git checkout --track -b ${branch} remotes/origin/${branch}"
    else
      git checkout --track -b "${branch}" "remotes/origin/${branch}"
    fi
  elif [[ "${isTag}" == 1 ]]; then
    echo "Checking out tag: ${branch}"
    if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
      sudo -H -u "${webUser}" bash -c "git checkout --no-track -b branch_${branch} tags/${branch}"
    else
      git checkout --no-track -b "branch_${branch}" "tags/${branch}"
    fi
  fi
fi

if [[ "${isBranch}" == 1 ]]; then
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "git pull"
  else
    git pull
  fi
fi

if [[ -d .git ]]; then
  echo "Removing Git directory"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "rm -rf .git"
  else
    rm -rf .git
  fi
fi

if [[ -f .gitignore ]]; then
  echo "Removing Git ignore file"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "rm -rf .gitignore"
  else
    rm -rf .gitignore
  fi
fi

if [[ -d ads ]]; then
  echo "Removing ADS directory"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "rm -rf ads"
  else
    rm -rf ads
  fi
fi

if [[ -d vagrant ]]; then
  echo "Removing Vagrant directory"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "rm -rf vagrant"
  else
    rm -rf vagrant
  fi
fi

if [[ -f Vagrantfile ]]; then
  echo "Removing Vagrant file"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "rm -rf Vagrantfile"
  else
    rm -rf Vagrantfile
  fi
fi

branchPath="${buildPath}/${branchPathName}"

if [[ -d "${branchPath}" ]]; then
  echo "Removing previous build path: ${branchPath}"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "rm -rf ${branchPath}/"
  else
    rm -rf "${branchPath:?}/"
  fi
fi

echo "Creating branch build path: ${branchPath}"
if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
  sudo -H -u "${webUser}" bash -c "mkdir -p ${branchPath}"
else
  mkdir -p "${branchPath}"
fi

if [[ "${magento}" == "yes" ]]; then
  echo "Copying Magento version file from: ${magentoVersionFile} to build path"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "cp ${magentoVersionFile} ${branchPath}"
  else
    cp "${magentoVersionFile}" "${branchPath}"
  fi

  fileName=$(basename "${magentoVersionFile}")

  cd "${branchPath}"

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

echo "Copying all files from GIT path: ${branchGitPath} to build path: ${buildPath}"
cp -rf "${branchGitPath}" "${branchPath}"

cd "${branchPath}"

if [[ "${composer}" == 1 ]]; then
  if [[ ! -f "${composerScript}" ]]; then
    echo "Missing composer script at: ${composerScript}"
    exit 1
  fi
  "${composerScript}" \
    -w "${branchPath}" \
    -u "${webUser}" \
    -g "${webGroup}" \
    -b "${phpExecutable}"
fi

echo "Creating vcs-info.txt"
echo "Version: ${branch}" > vcs-info.txt
echo "Build-Date: $(LC_ALL=en_US.utf8 date +"%Y-%m-%d %H:%M:%S %z")" >> vcs-info.txt

branchFile="${buildPath}/${branchPathName}.tar.gz"

if [[ -f "${branchFile}" ]]; then
  echo "Removing previous archive at: ${branchFile}"
  if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
    sudo -H -u "${webUser}" bash -c "rm -rf ${branchFile}"
  else
    rm -rf "${branchFile}"
  fi
fi

echo "Creating archive of branch: ${branchFile}"
if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
  sudo -H -u "${webUser}" bash -c "tar -zcf ${branchFile} ."
else
  tar -zcf "${branchFile}" .
fi

cd ..

echo "Removing branch build path: ${branchPath}"
if [[ "${webUser}" != "${currentUser}" ]] || [[ "${webGroup}" != "${currentGroup}" ]]; then
  sudo -H -u "${webUser}" bash -c "rm -rf ${branchPath}"
else
  rm -rf "${branchPath}"
fi
