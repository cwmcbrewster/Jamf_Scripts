#!/bin/bash

# Automatically download and install the latest Firefox

# Variables
#currentVersion=$(curl -s https://www.mozilla.org/en-US/firefox/new/ | grep "data-esr-versions" | awk -F"data-esr-versions=" '{print $NF}' | cut -d\" -f 2)
appName="Firefox.app"
appProcessName="firefox"
downloadUrl="https://download.mozilla.org/?product=firefox-esr-pkg-latest-ssl&os=osx&lang=en-US" # Oldest supported ESR version
#downloadUrl="https://download.mozilla.org/?product=firefox-esr-next-pkg-latest-ssl&os=osx&lang=en-US" # Latest ESR version available
pkgName=$(curl -sIL "${downloadUrl}" | grep -m 1 "^Location:" | cut -d' ' -f2 | awk -F'/' '{print $NF}' | sed -e 's/%20/ /g' | sed -e 's/[[:space:]]*$//')
#pkgName="Firefox esr.pkg"

tmpDir=$(mktemp -d)
echo "Temp dir set to ${tmpDir}"

processCheck () {
  if [[ -n $(pgrep -x "${appProcessName}") ]]; then
    echo "${appProcessName} is currently running"
    echo "Aborting install"
    exit 0
  else
    echo "${appProcessName} not currently running"
  fi
}

tryDownload () {
  curl -LSs "${downloadUrl}" -o "${tmpDir}/${pkgName}"
  if [[ $? -eq 0 ]]; then
    echo "Download successful"
    tryDownloadState=1
  else
    echo "Download unsuccessful"
    tryDownloadCounter=$((tryDownloadCounter+1))
  fi
}

versionCheck () {
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

# Download PKG file into tmpDir (60 second timeouet)
echo "Starting download"
tryDownloadState=0
tryDownloadCounter=0
while [[ ${tryDownloadState} -eq 0 && ${tryDownloadCounter} -le 60 ]]; do
  processCheck
  tryDownload
  sleep 1
done

# Check for successful download
if [[ ! -f "${tmpDir}/${pkgName}" ]]; then
  echo "Download failed"
  exit 1
fi

# Install package
echo "Starting install"
installer -pkg "${tmpDir}/${pkgName}" -target /

# Remove tmp dir
rm -R "${tmpDir}"

# List version and exit with error code if not found
versionCheck
if [[ ${versionCheckStatus} -eq 0 ]]; then
  exit 1
fi
