#!/bin/bash

# Use this script to notify end user about there password expiration
# Do this changes: Jamf Pro Settings > System > Cloud identity providers > (Name of you Cloud IDP) > Mapping Tab > Edit > change the phone field with "Lastpasswordchangedatetime" save it.
# Create API client and API Role in jamf pro > Settings > System > API roles and clients
# Client ID and secret used to authenticate to the Jamf Pro API
# ONLY needs the "Read" privilege for the "Computer" object and nothing else
# Client ID and secret used to authenticate to the Jamf Pro API
# ONLY needs the "Read" privilege for the "Computer" object and nothing else


client_id='client_id here'
client_secret='client_secret here'
jamf_pro_url='https://companyname.jamfcloud.com'
icon="Icon path here"

# ---------- SCRIPT LOGIC BELOW - DO NOT MODIFY ---------- #

curUser=$(ls -l /dev/console | cut -d " " -f 4)

loggedInUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
loggedInUserFullname=$( id -F "${loggedInUser}" )
loggedInUserFirstname=$( echo "$loggedInUserFullname" | sed -E 's/^.*, // ; s/([^ ]*).*/\1/' | sed 's/\(.\{25\}\).*/\1…/' | awk '{print toupper(substr($0,1,1))substr($0,2)}' )

# Get the computer's serial number
serial_number=$(system_profiler SPHardwareDataType | awk '/Serial Number/{print $4}')

# Get an access token based on the client ID and secret above
token_response=$(curl --silent --location --request POST "${jamf_pro_url}/api/oauth/token" \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "client_id=${client_id}" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_secret=${client_secret}")

access_token=$(echo "$token_response" | plutil -extract access_token raw -)

# Pull down the inventory record and extract the "phone" attribute, which is the "lastPasswordChangeDateTime" attribute
inventory_response=$(curl -sX GET "${jamf_pro_url}/JSSResource/computers/serialnumber/${serial_number}" \
  --header "Authorization: Bearer ${access_token}" \
  --header "Accept: application/xml")

# Extract the "phone" attribute from the response
lastPasswordChangeDateTime=$(xmllint --xpath '//computer/location/phone_number/text()' - <<<"$inventory_response")

# Ensure lastPasswordChangeDateTime is parsed correctly
newDate=$(date -j -u -v+90d -f "%Y-%m-%dT%H:%M:%SZ" "$lastPasswordChangeDateTime" "+%Y-%m-%d")

passnewDate=$(date -j -u -v+90d -f "%Y-%m-%dT%H:%M:%SZ" "$lastPasswordChangeDateTime" "+%Y-%b-%d")

# Get the current date in the same format
currentDate=$(date "+%Y-%m-%d")

# Calculate the difference in days between the expiration date and the current date
# Convert dates to seconds since the epoch, then find the difference in days
remainingDays=$(( ($(date -jf "%Y-%m-%d" "$newDate" +%s) - $(date -jf "%Y-%m-%d" "$currentDate" +%s)) / 86400 ))

# Check if the date calculation is negative, and adjust accordingly
if [ "$remainingDays" -lt 0 ]; then
  remainingDays=0
fi


jamfHelper="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"
windowType="hud"
description="Hello $loggedInUserFirstname

Your network password will expire in $remainingDays days on $passnewDate. To avoid being locked out of your account please click on the 'Change' button or select 'Postpone' to be reminded later.

If you want to change your password at any time that is most convenient for you, open the Jamf Self-Service portal and search for 'Password Reset'.



."


button1="Change"
button2="Postpone"
title="Password will expire soon"
alignDescription="left"
alignHeading="center"
defaultButton="1"
timeout="86400"


# JAMF Helper window as it appears for targeted computers
userChoice=$("$jamfHelper" -windowType "$windowType" -lockHUD -title "$title" -timeout "$timeout" -defaultButton "$defaultButton" -icon "$icon" -description "$description" -alignDescription "$alignDescription" -alignHeading "$alignHeading" -button1 "$button1" -button2 "$button2")

# If user selects "UPDATE"
if [ "$userChoice" == "0" ]; then
   echo "User clicked Reset."
   # Opening password reset URL in Safari
   open -a Safari https://passwordreset.microsoftonline.com/
# If user selects "Cancel"
elif [ "$userChoice" == "2" ]; then
   echo "User clicked Cancel or timeout was reached; now exiting."
   exit 0
fi
