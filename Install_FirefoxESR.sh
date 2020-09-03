#!/bin/bash

# Automatically download and install the latest Firefox

# Variables
appName="Firefox.app"
appProcessName="firefox"
#downloadUrl="https://download.mozilla.org/?product=firefox-esr-pkg-latest-ssl&os=osx&lang=en-US" # Oldest supported ESR version
downloadUrl="https://download.mozilla.org/?product=firefox-esr-next-pkg-latest-ssl&os=osx&lang=en-US" # Latest ESR version available
pkgName=$(curl -sIL "${downloadUrl}" | grep -m 1 "^Location:" | cut -d' ' -f2 | awk -F'/' '{print $NF}' | sed -e 's/%20/ /g' | sed -e 's/[[:space:]]*$//')

tmpDir=$(mktemp -d)
echo "Temp dir set to ${tmpDir}"

function processCheck {
  if [[ -n $(pgrep -x "${appProcessName}") ]]; then
    echo "${appProcessName} is currently running"
    echo "Aborting install"
    exit 0
  else
    echo "${appProcessName} not currently running"
  fi
}

function tryDownload {
  curl -LSs "${downloadUrl}" -o "${tmpDir}/${pkgName}"
}

function versionCheck {
  appPath="/Applications/${appName}"

  if [[ -d "${appPath}" ]]; then
    echo "${appName} version is $(defaults read "${appPath}"/Contents/Info.plist CFBundleShortVersionString)"
    versionCheckStatus=1
  else
    echo "${appName} not installed"
    versionCheckStatus=0
  fi
}

# Start

# List version
versionCheck

# Exit if app is running
processCheck

# Download PKG file into tmpDir
tryDownload

# Check curl exit code and try again in 30 seconds if it was not successful
if [[ ! $? -eq 0 ]]; then
  echo "Waiting 30 seconds to try again..."
  sleep 30
  processCheck
  tryDownload
fi

# Check for successful download
if [[ ! -f "${tmpDir}/${pkgName}" ]]; then
    echo "Download unsuccessful"
    exit 1
fi

# Install package
installer -pkg "${tmpDir}/${pkgName}" -target /

# Remove downloaded PKG file
rm -f "${tmpDir}/${pkgName}"

# List version and exit with error code if not found
versionCheck
if [[ ${versionCheckStatus} -eq 0 ]]; then
  exit 1
fi
