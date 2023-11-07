#!/bin/zsh

# Automatically download and Unity Hub

if [[ -z $4 ]]; then
  echo "Version not specified"
  exit 1
fi

# Variables
appName="Unity Hub.app"
appPath="/Applications/${appName}"
appProcessName="Unity Hub"
dmgName="UnityHubSetup.dmg"
dmgVolumePath="/Volumes/Unity Hub $4"
downloadUrl="https://public-cdn.cloud.unity3d.com/hub/prod"

cleanup () {
  if [[ -f "${tmpDir}/${dmgName}" ]]; then
    if rm -f "${tmpDir}/${dmgName}"; then
      echo "Removed file ${tmpDir}/${dmgName}"
    fi
  fi
  if [[ -d "${tmpDir}" ]]; then
    if rm -R "${tmpDir}"; then
      echo "Removed directory ${tmpDir}"
    fi
  fi
  if [[ -d "${dmgVolumePath}" ]]; then
    if hdiutil detach "${dmgVolumePath}" -quiet; then
      echo "Unmounted DMG"
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
  if curl -LSs "${downloadUrl}/${dmgName}" -o "${tmpDir}/${dmgName}"; then
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

# Make sure volume is not already mounted and unmount if needed
if [[ -d "${dmgVolumePath}" ]]; then
  echo "${dmgVolumePath} already in use. Attempting to unmount"
  hdiutil detach "${dmgVolumePath}"
fi

# Download dmg file into tmp dir (60 second timeout)
tryDownloadState=0
tryDownloadCounter=0
while [[ ${tryDownloadState} -eq 0 && ${tryDownloadCounter} -le 60 ]]; do
  processCheck
  createTmpDir
  tryDownload
  sleep 1
done

# Check for successful download
if [[ ! -f "${tmpDir}/${dmgName}" ]]; then
  echo "Download unsuccessful"
  cleanup
  exit 1
fi

# Mount dmg file
if hdiutil attach "${tmpDir}/${dmgName}" -nobrowse -quiet; then
  echo "Mounted DMG"
else
  echo "Failed to mount DMG"
  cleanup
  exit 1
fi

# Check for expected dmg path
if [[ ! -d "${dmgVolumePath}" ]]; then
  echo "Could not locate ${dmgVolumePath}"
  cleanup
  exit 1
fi

# Remove app if already installed
if [[ -d "${appPath}" ]]; then
  if rm -R "${appPath}"; then
    echo "Removed existing ${appName} from /Applications directory"
  else
    echo "Failed to remove existing ${appName} from /Applications directory"
    cleanup
    exit 1
  fi
fi

# Copy application to /Applications
if cp -R "${dmgVolumePath}/${appName}" /Applications/; then
  echo "Copied ${appName} to /Applications directory"
else
  echo "Failed to copy ${appName} to /Applications directory"
fi

# Remove tmp dir and downloaded dmg file
cleanup

# List version and exit with error code if not found
versionCheck
if [[ ${versionCheckStatus} -eq 0 ]]; then
  exit 1
fi
