#!/bin/bash

# You will want to customize this script for your environment starting at line 128.
# Everything from 127 down is just an example from my environment. 

# Variables

# Set these for your environment
jamfHelperHeading='My Org'
jamfHelperIconPath='/Library/Application\ Support/MyOrg/Logo.png'
launchAgentName='org.my.jamfHelperSplashScreen'

# You probably don't need to change these
launchAgentPath="/Library/LaunchAgents/${launchAgentName}.plist"
jamfHelperPath='/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper'

# Functions

startSplashScreen () {

# Check for user not logged in
if [[ -z "$loggedInUser" ]]; then
  
  # Remove existing LaunchAgent
  if [[ -f ${launchAgentPath} ]]; then
    rm ${launchAgentPath}
  fi

  # Write LaunchAgent to load jamfHelper script
  defaults write ${launchAgentPath} KeepAlive -bool true
  defaults write ${launchAgentPath} Label ${launchAgentName}
  defaults write ${launchAgentPath} LimitLoadToSessionType "LoginWindow"
  defaults write ${launchAgentPath} ProgramArguments -array-add "$jamfHelperPath"
  defaults write ${launchAgentPath} ProgramArguments -array-add "-windowType"
  defaults write ${launchAgentPath} ProgramArguments -array-add "fs"
  defaults write ${launchAgentPath} ProgramArguments -array-add "-heading"
  defaults write ${launchAgentPath} ProgramArguments -array-add "$jamfHelperHeading"
  defaults write ${launchAgentPath} ProgramArguments -array-add "-description"
  defaults write ${launchAgentPath} ProgramArguments -array-add "$message"
  defaults write ${launchAgentPath} ProgramArguments -array-add "-icon"
  defaults write ${launchAgentPath} ProgramArguments -array-add "$jamfHelperIconPath"
  defaults write ${launchAgentPath} RunAtLoad -bool true 
  chown root:wheel ${launchAgentPath}
  chmod 644 ${launchAgentPath}
  echo "Created Launch Agent to run jamfHelper"
  
  # Kill/restart the loginwindow process to load the LaunchAgent
  echo "Ready to lock screen. Restarting loginwindow..."
  if [[ ${osvers} -le 14 ]]; then
    killall loginwindow
  fi
  if [[ ${osvers} -ge 15 ]]; then
    launchctl kickstart -k system/com.apple.loginwindow # kickstarting the login window results in a runaway SecurityAgent process in macOS 10.15.0 to 10.15.2
    sleep 0.5
    killall -9 SecurityAgent # kill the runaway SecurityAgent process
  fi
fi
}

killSplashScreen () {
# Remove existing LaunchAgent and restart login window
if [[ -f ${launchAgentPath} ]]; then
  echo "Removing LaunchAgent located at ${launchAgentPath}"
  rm ${launchAgentPath}
fi

echo "Restarting loginwindow..."
killall loginwindow
}

removeLaunchAgentAtReboot () {
# Create a self-destructing LaunchDaemon to remove our LaunchAgent at next startup
if [[ -f ${launchAgentPath} ]]; then
  launchDaemonName="${launchAgentName}.remove"
  launchDaemonPath="/Library/LaunchDaemons/${launchDaemonName}.plist"
  defaults write ${launchDaemonPath} Label "${launchDaemonName}"
  defaults write ${launchDaemonPath} ProgramArguments -array-add "rm"
  defaults write ${launchDaemonPath} ProgramArguments -array-add "${launchAgentPath}"
  defaults write ${launchDaemonPath} ProgramArguments -array-add "${launchDaemonPath}"
  defaults write ${launchDaemonPath} RunAtLoad -bool true
  chown root:wheel ${launchDaemonPath}
  chmod 644 ${launchDaemonPath}
  echo "Created Launch Daemon to remove ${launchAgentPath}"
fi
}

# Start script

osvers=$(sw_vers -productVersion | awk -F. '{print $2}')

# Only proceed if macOS version is 10.13 or higer
if [[ ${osvers} -le 12 ]]; then
  echo "macOS version 10.$osvers not supported."
  exit 0
fi

# Get currently logged in user
loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )

# Wait for _mbsetupuser to not be logged in (used by Apple for setup screens)
while [[ $loggedInUser = "_mbsetupuser" ]]
do
  sleep 5
  loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
  #echo "Waiting for _mbsetupuser"
done

# Check for logged in user and exit if true
if [[ -n "$loggedInUser" ]]; then
  echo "$loggedInUser is logged in. Exiting..."
  exit 0
fi

message="Starting Final Setup..."
startSplashScreen

# Keep this Mac from dozing off
caffeinate -d -i -s -t 7200 &

# Prevent Jamf check-in policies from running until next reboot
launchctl unload /Library/LaunchDaemons/com.jamfsoftware.task.1.plist
launchctl unload /Library/LaunchDaemons/com.jamfsoftware.jamf.daemon.plist

# Run Jamf enrollment policies (custom these as needed for your environment)
# When you want to change the jamfHeper message, set the message variable and run startSplashScreen
# Either run killSplashScreen at the end of your script or use removeLaunchAgentAtReboot if you will be restarting the computer

# Set computer name / join AD
jamf policy -event enrollment_02

# Enable SSH
jamf policy -event enrollment_03

# Set Energy Saver
jamf policy -event enrollment_04

message="Installing Canon Print Drivers..."
startSplashScreen
jamf policy -event enrollment_05

message="Installing HP Print Drivers..."
startSplashScreen
jamf policy -event enrollment_06

message="Installing Microsoft Office..."
startSplashScreen
jamf policy -event enrollment_07

# Update inventory to avoid running unneccessary startup policies
message="Updating Inventory..."
startSplashScreen
jamf recon

# Run Jamf startup policies
message="Checking Policies..."
startSplashScreen
jamf policy -event startup

# Cleanup (anything you might want to do before starting software updates and/or restarting the computer)
jamf policy -event enrollment_15
removeLaunchAgentAtReboot

# Check for software updates and reboot
message="Checking Software Updates..."
startSplashScreen
jamf policy -event enrollment_20
