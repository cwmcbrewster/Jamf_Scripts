#!/bin/bash

osvers=$(sw_vers -productVersion | awk -F. '{print $2}')

#Cleanup files from prior enrollment
if [ -f /private/tmp/splash_screen.sh ];then
  echo "Removing /private/tmp/splash_screen.sh"
  rm /private/tmp/splash_screen.sh
fi
if [ -f /Library/LaunchAgents/ORG.computer_setup.plist ];then
  echo "Removing /Library/LaunchAgents/ORG.computer_setup.plist"
  rm /Library/LaunchAgents/ORG.computer_setup.plist
fi

#Get currently logged in user
loggedInUser=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`

#Wait for _mbsetupuser to not be logged in (used by Apple for setup screens)
while [[ $loggedInUser = "_mbsetupuser" ]]
do
  sleep 5
  loggedInUser=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`
  #echo "Waiting for _mbsetupuser"
done

#Check for logged in user and exit if true (10.12+)
if [[ ${osvers} -ge 12 ]];then
  if [[ -n "$loggedInUser" ]];then
    echo "$loggedInUser is logged in. Exiting..."
    exit 0
  fi
fi

#Check if logged in user is admin and continue if true (10.11)
if [[ ${osvers} -eq 11 ]];then
  if [[ $loggedInUser = "admin" ]];then
    /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -heading "My Organization" -description "Finishing Setup..." -icon "/private/tmp/ORG_Logo.png" &
  else
    echo "Logged in user is not admin. Exiting..."
    exit 0
  fi
fi

#Check for user not logged in
if [ -z "$loggedInUser" ];then
  #Write jamfHelper splash screen script
  echo "#!/bin/bash" >> /private/tmp/splash_screen.sh
  echo "\"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper\" -windowType fs -heading \"My Organization\" -description \"Finishing Setup...\" -icon \"/private/tmp/ORG_Logo.png\"" >> /private/tmp/splash_screen.sh
  chmod +x /private/tmp/splash_screen.sh

  #Write LaunchAgent to load jamfHelper script
  defaults write /Library/LaunchAgents/ORG.computer_setup.plist Label "ORG.computer_setup"
  defaults write /Library/LaunchAgents/ORG.computer_setup.plist LimitLoadToSessionType "LoginWindow"
  defaults write /Library/LaunchAgents/ORG.computer_setup.plist ProgramArguments -array
  defaults write /Library/LaunchAgents/ORG.computer_setup.plist KeepAlive -bool true
  defaults write /Library/LaunchAgents/ORG.computer_setup.plist RunAtLoad -bool true
  /usr/libexec/PlistBuddy -c "Add ProgramArguments: string /private/tmp/splash_screen.sh" /Library/LaunchAgents/ORG.computer_setup.plist

  chown root:wheel  /Library/LaunchAgents/ORG.computer_setup.plist
  chmod 644 /Library/LaunchAgents/ORG.computer_setup.plist
  echo "Created Launch Agent to run jamfHelper"

  #Kill/restart the loginwindow process to load the LaunchAgent
  echo "Ready to lock screen. Restarting loginwindow process..."
  kill -9 $(ps axc | awk '/loginwindow/{print $1}')
fi

#Disable local admin account
id -u admin
if [ $? -eq 0 ];then
 echo "admin account exists. disabling..."
 pwpolicy -u admin -disableuser
fi

#Run enrollment policies
jamf policy -event enrollment_02
jamf policy -event enrollment_03
jamf policy -event enrollment_04
jamf policy -event enrollment_05
jamf policy -event enrollment_06
jamf policy -event enrollment_07

#Enable local admin account
id -u admin
if [ $? -eq 0 ];then
 echo "admin account exists. enabling..."
 pwpolicy -u admin -enableuser
fi

#Last enrollment policy (cleanup and reboot)
jamf policy -event enrollment_20
