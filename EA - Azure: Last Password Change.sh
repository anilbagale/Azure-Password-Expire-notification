#!/bin/bash

# Use this script as EA
# This script is to pull the last password change date from Azure.
# Do this changes: Jamf Pro Settings > System > Cloud identity providers > (Name of you Cloud IDP) > Mapping Tab > Edit > change the phone field with "Lastpasswordchangedatetime" save it.
# Create API client and API Role in jamf pro > Settings > System > API roles and clients
# Client ID and secret used to authenticate to the Jamf Pro API
# ONLY needs the "Read" privilege for the "Computer" object and nothing else




client_id='client_id here'
client_secret='client_secret here'
jamf_pro_url='https://companyname.jamfcloud.com'

# ---------- SCRIPT LOGIC BELOW - DO NOT MODIFY ---------- #

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

# Format the date for the extension attribute and for it to be used as a date criteria in a smart groups
formattedDate=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$lastPasswordChangeDateTime" "+%Y-%m-%d %H:%M:%S")

# Output the formatted date to the extension attribute
echo "<result>$formattedDate</result>"
