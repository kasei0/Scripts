#!/bin/bash

# NEED jq module
# usage: './domainReputation.sh domain.tld'
## look up domain reputation from spamhaus database
## Apply api license first.
# Define variables
####### replace this #######
username="USERNAME"
password="PASSWORD"
############################
realm="intel"
uri="https://api.spamhaus.org"
token_file="token_info.json"
beijing_offset=$((8*3600)) # Beijing is UTC+8

domain="$1"

# Function to refresh token
refresh_token() {
  response=$(curl -s -d "{\"username\":\"$username\", \"password\":\"$password\", \"realm\":\"$realm\"}" "$uri/api/v1/login")
  token=$(echo $response | jq -r '.token')
  expires=$(echo $response | jq -r '.expires')

  # Convert and format expiration timestamp
  expires_date=$(date -d @"$expires" -u +"%Y-%m-%dT%H:%M:%SZ")
  beijing_time=$(date -d @"$(($expires + $beijing_offset))" +"%Y-%m-%d %H:%M:%S")

  # Save token and formatted expiration to file
  echo $response | jq ". + {expires_date: \"$expires_date\", beijing_expires: \"$beijing_time\"}" > $token_file
}

# Check if token is expired
current_ts=$(date +%s)
if [ -f "$token_file" ]; then
  expires=$(jq -r '.expires' < $token_file)
  if [ "$current_ts" -ge "$expires" ]; then
    echo "Token expired, refreshing..."
    refresh_token
  fi
else
  echo "Token file not found, obtaining new token..."
  refresh_token
fi

# Read token
token=$(jq -r '.token' < $token_file)

# Define domain for querying


# Define filename for results based on current Beijing time
results_file="$(date -d @$((current_ts + beijing_offset)) +"%Y%m%d-%H-%M")-$domain"

# Perform curl requests and gather results
curl -s "$uri/api/intel/v2/byobject/domain/$domain" -H "Authorization: Bearer $token" >> "$results_file"
curl -s "$uri/api/intel/v2/byobject/domain/$domain/dimensions" -H "Authorization: Bearer $token" >> "$results_file"
curl -s "$uri/api/intel/v2/byobject/domain/$domain/contexts" -H "Authorization: Bearer $token" >> "$results_file"
curl -s "$uri/api/intel/v2/byobject/domain/$domain/listing" -H "Authorization: Bearer $token" >> "$results_file"
curl -s "$uri/api/intel/v2/byobject/domain/$domain/senders" -H "Authorization: Bearer $token" >> "$results_file"
curl -s "$uri/api/intel/v2/byobject/domain/$domain/ns" -H "Authorization: Bearer $token" >> "$results_file"
curl -s "$uri/api/intel/v2/byobject/domain/$domain/a" -H "Authorization: Bearer $token" >> "$results_file"

# Use jq to format the combined JSON nicely
jq . "$results_file" > temp_file && mv temp_file "$results_file"

echo "Data gathering complete. Results saved to $results_file."
