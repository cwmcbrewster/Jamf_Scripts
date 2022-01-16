#!/bin/zsh

# Automatically download and install the latest zoom.us

# Variables
appName="zoom.us.app"
appPath="/Applications/${appName}"
appProcessName="zoom.us"
downloadUrl="https://zoom.us/client/latest"
pkgName="ZoomInstallerIT.pkg"

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
    cleanup
    exit 0
  else
    echo "${appProcessName} not currently running"
  fi
}

tryDownload () {
  if curl -LSs "${downloadUrl}/${pkgName}" -o "${tmpDir}/${pkgName}"; then
    echo "Download successful"
    tryDownloadState=1
  else
    echo "Download unsuccessful"
    tryDownloadCounter=$((tryDownloadCounter+1))
  fi
}

versionCheck () {
  if [[ -d "${appPath}" ]]; then
    echo "${appName} version is $(defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString)"
    versionCheckStatus=1
  else
    echo "${appName} not installed"
    versionCheckStatus=0
  fi
}

# Start

# List version
versionCheck

# Download PKG file into ${tmpDir} (60 second timeout)
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
    echo "Download unsuccessful"
    cleanup
    exit 1
fi

# Install package
echo "Starting install"
installer -pkg "${tmpDir}/${pkgName}" -target /

# Remove tmp dir and downloaded pkg file
cleanup

# List version and exit with error code if not found
versionCheck
if [[ ${versionCheckStatus} -eq 0 ]]; then
  exit 1
fi
