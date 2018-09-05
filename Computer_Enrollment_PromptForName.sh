#!/bin/sh

# Get serial number
serialNumber=`system_profiler SPHardwareDataType | awk '/Serial/ {print $4}'`

# Set name to serial number (in case name is not set by user)
scutil --set ComputerName $serialNumber
scutil --set LocalHostName $serialNumber
scutil --set HostName $serialNumber

# Get currently logged in user
loggedInUser=`python -c 'from SystemConfiguration import SCDynamicStoreCopyConsoleUser; import sys; username = (SCDynamicStoreCopyConsoleUser(None, None, None) or [None])[0]; username = [username,""][username in [u"loginwindow", None, u""]]; sys.stdout.write(username + "\n");'`

# Only proceed if _mbsetupuser is logged in (used by Apple for setup screens)
if [[ ! $loggedInUser = "_mbsetupuser" ]];then
  echo "Logged in user is not _mbsetupuser. Exiting..."
  exit 0
fi

# Get the logged in UID
loggedInUID=$(id -u $loggedInUser)

# Prompt for Computer Name as the user
/bin/launchctl asuser $loggedInUID sudo -iu $loggedInUser whoami
computerName=$(/bin/launchctl asuser "${loggedInUID}" sudo -iu "${loggedInUser}" /usr/bin/osascript<<EOL
tell application "System Events"
activate
with timeout of 900 seconds
set answer to text returned of (display dialog "Set Computer Name" with title "MyOrganization" default answer "$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')")
end timeout
end tell
EOL)

# Check to make sure $computerName is set
if [[ -z $computerName ]];then
  echo "Computer Name not set. Exiting..."
  exit 0
fi

# Set name using variable created above
computerName=`echo $computerName | tr '[:lower:]' '[:upper:]'`
scutil --set ComputerName $computerName
scutil --set LocalHostName $computerName
scutil --set HostName $computerName

echo "Computer Name set to $computerName"

# Confirm Computer Name
/bin/launchctl asuser "${loggedInUID}" sudo -iu "${loggedInUser}" /usr/bin/osascript<<EOL
tell application "System Events"
activate
display dialog "Computer Name set to " & host name of (system info) buttons {"OK"} default button 1 with title "MyOrganization" giving up after 5
end tell
EOL
