#!/bin/zsh

# Automatically download and install the latest Firefox

# Variables
#currentVersion=$(curl -s https://www.mozilla.org/en-US/firefox/new/ | grep "data-esr-versions" | awk -F"data-esr-versions=" '{print $NF}' | cut -d\" -f 2)
appName="Firefox.app"
appPath="/Applications/${appName}"
appProcessName="firefox"
downloadUrl="https://download.mozilla.org/?product=firefox-esr-pkg-latest-ssl&os=osx&lang=en-US" # Oldest supported ESR version
#downloadUrl="https://download.mozilla.org/?product=firefox-esr-next-pkg-latest-ssl&os=osx&lang=en-US" # Latest ESR version available
#curlPkgName="Firefox%20${currentVersion}esr.pkg"
#pkgName=$(curl -sIL "${downloadUrl}" | grep -m 1 "^Location:" | cut -d' ' -f2 | awk -F'/' '{print $NF}' | sed -e 's/%20/ /g' | sed -e 's/[[:space:]]*$//')
pkgName="Firefox_esr.pkg"

cleanup () {
  if [[ -f "${tmpDir}/${pkgName}" ]]; then
    if rm -f "${tmpDir}/${pkgName}"; then
      echo "Removed file ${tmpDir}/${pkgName}"
    fi
  fi
  if [[ -d "${tmpDir}" ]]; then
    if rm -R "${tmpDir}"; then
      echo "Removed directory ${tmpDir}"
    fi
  fi
}

createTmpDir () {
  if [ -z ${tmpDir+x} ]; then
    tmpDir=$(mktemp -d)
    echo "Temp dir set to ${tmpDir}"
  fi
}

processCheck () {
  if pgrep -x "${appProcessName}" > /dev/null; then
    echo "${appProcessName} is currently running"
    echo "Aborting install"
    exit 0
  else
    echo "${appProcessName} not currently running"
  fi
}

tryDownload () {
  if curl -LSs "${downloadUrl}" -o "${tmpDir}/${pkgName}"; then
    echo "Download successful"
    tryDownloadState=1
  else
    echo "Download unsuccessful"
    tryDownloadCounter=$((tryDownloadCounter+1))
  fi
}

versionCheck () {
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

# Download pkg file into tmp dir (60 second timeouet)
tryDownloadState=0
tryDownloadCounter=0
while [[ ${tryDownloadState} -eq 0 && ${tryDownloadCounter} -le 60 ]]; do
  processCheck
  createTmpDir
  tryDownload
  sleep 1
done

# Check for successful download
if [[ ! -f "${tmpDir}/${pkgName}" ]]; then
  echo "Download failed"
  cleanup
  exit 1
fi

# Install package
echo "Starting install"
installer -pkg "${tmpDir}/${pkgName}" -target /

# Remove tmp dir and downloaded pkg package
cleanup

# List version and exit with error code if not found
versionCheck
if [[ ${versionCheckStatus} -eq 0 ]]; then
  exit 1
fi
