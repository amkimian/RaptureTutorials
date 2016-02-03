#!/bin/bash
# TODO: update HOST
HOST="http://192.168.99.100:8080"

read -p "Enter Etienne User: " user
read -s -p "Enter Etienne Password: " pass
echo $'\n'

hashpass=$(echo $pass | md5)

login_url="$HOST/login/login?user=$user&password=$hashpass"
env_vars_url="$HOST/curtisscript/getEnvInfo?username=$user"

function validate_curl_response {
  curl_exit_code=$1
  http_status_code=$2
  error_message=$3

  if [[ $curl_exit_code -ne 0 || $http_status_code -ne 200 ]] ; then
    echo $error_message
    echo "Curl Exit Code: $curl_exit_code     HTTP Status Code: $http_status_code"
    exit 1
  fi
}

curl_results=$( curl -qSsw '\n%{http_code}' --cookie-jar .cookiefile $login_url )
validate_curl_response $? $(echo "$curl_results" | tail -n1) "There was a problem logging into $HOST."

# get environment variable data, append HTTP status code in separate line
curl_results=$( curl -qSsw '\n%{http_code}' --cookie .cookiefile $env_vars_url )
validate_curl_response $? $(echo "$curl_results" | tail -n1) "There was a problem retrieving the environment variables from $HOST."
env_data=$(echo "$curl_results" | sed \$d) #strip http status

# write the export statements to a file to be sourced later
env_var_filename=".rapture_client.$RANDOM.env"

IFS='|' read -a env_var_array <<< "$env_data"

for pair in "${env_var_array[@]}"
do
  IFS=',' read -a pair_array <<< "$pair"

  array_length=${#pair_array[@]}
  if [[ $array_length -ne 2 ]] ; then
    echo "The data retrieved from $env_vars_url is invalid."
    exit 1
  fi
  
  var_name=${pair_array[0]}
  var_val=${pair_array[1]}

  echo "export $var_name=$var_val" >> $env_var_filename
done

# Also write a welcome banner to the file and change the prompt so it's easier for the user 
# to know that they are in a screen session.
cat << 'EOF' >> $env_var_filename

#banner
BLUE="\033[01;34m"
WHITE="\033[01;37m"
echo -e "${BLUE}******************************************************************************"
echo -e "${BLUE}**                                                                          **"
echo -e "${BLUE}**                            Welcome To Rapture                            **"
echo -e "${BLUE}**                                                                          **"
echo -e "${BLUE}******************************************************************************"
echo -e "\033[0m \033[39m"

#prompt
PS1="Rapture: \W \u\$ "
EOF

# start up a new session in screen and source the file we wrote
screen -h 2000 -S Rapture sh -c "exec /bin/bash -init-file ./$env_var_filename"

# will execute after screen session exits
rm $env_var_filename
