#!/bin/zsh

# Unload the Jamf Connect launch agent
loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }' )
if [[ ${loggedInUser} ]]; then
  loggedInUID=$(id -u "${loggedInUser}")

  if [[ $(/bin/launchctl asuser "${loggedInUID}" sudo -iu "${loggedInUser}" launchctl list | grep "com.jamf.connect") ]]; then
    if [[ -f '/Library/LaunchAgents/com.jamf.connect.plist' ]]; then
      echo "Stopping com.jamf.connect launch agent..."
      /bin/launchctl asuser "${loggedInUID}" sudo -iu "${loggedInUser}" launchctl unload '/Library/LaunchAgents/com.jamf.connect.plist'
      while /bin/launchctl asuser "${loggedInUID}" sudo -iu "${loggedInUser}" launchctl list | grep "com.jamf.connect"; do
        sleep 1
      done
      echo 'Done'
    fi
  fi
  
fi

# Delete Jamf Connect launch agent
if [[ -f '/Library/LaunchAgents/com.jamf.connect.plist' ]]; then
  echo "Deleting /Library/LaunchAgents/com.jamf.connect.plist..."
  if rm '/Library/LaunchAgents/com.jamf.connect.plist'; then
    echo "Success"
  else
    echo "Fail"
  fi
fi

# Delete Jamf Connect.app symbolic link
if [[ -h '/Applications/Jamf Connect.app' ]]; then
  echo "Deleting /Applications/Jamf Connect.app link..."
  if rm '/Applications/Jamf Connect.app'; then
    echo 'Success'
  else
    echo 'Fail'
  fi
fi
