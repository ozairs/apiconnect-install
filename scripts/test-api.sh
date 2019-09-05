#! /bin/sh

nice_echo() {
    echo "\n\033[1;36m >>>>>>>>>> $1 <<<<<<<<<< \033[0m\n"
}

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# no parameters passed, using default config file
if [ $# -eq 0 ]; then
    #using default config file
    if [ -e config.cfg ]; then
        source config.cfg
        echo 'Using default config file at ' ${CURRENT_DIR}/config.cfg 
    else 
        echo 'No config file passed and default config file is not available at ' ${CURRENT_DIR}/config.cfg 
        exit
    fi
# usage function
elif [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  echo "Usage: `basename $0` [OPTION] [FILE]...
  Options:
  -h, --help        Display this help and exit
  "
  exit 0
# config file passed as argument
else 
    FILENAME=$1 #get filename
    if [ -e $FILENAME ]; then
        source $FILENAME; # load the file
        echo 'Using config file located at ' $FILENAME
    else 
        echo 'Bad config file passed at ' $FILENAME
        exit
    fi
fi

RED='\n\033[1;31m'
GREEN='\n\033[1;32m'
END_COLOR='\033[0m'

# ******************** Step 1. Invoke Hello World API  ********************
nice_echo "Step 1. Invoke Hello World API"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" ${DP_APIGW_ENDPOINT}/${pORG_NAME}/${CATALOG_NAME}/utility/ping`

RESPONSE_JSON=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_JSON == null ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}"
 echo 'Failed call with error' $RESPONSE
elif [[ $RESPONSE_JSON == '' ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}"
 echo 'Failed call with error' $RESPONSE 
else
  echo "${GREEN}SUCCESS${END_COLOR}"
  echo 'Sucessfully retrieved item ' $RESPONSE
fi

# ******************** Step 2. Invoke Basic Auth API ********************
nice_echo "Step 2. Invoke Basic Auth API"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Authorization: Basic c3Bvb246c3Bvb24=" -H "Accept: application/json" ${DP_APIGW_ENDPOINT}/${pORG_NAME}/${CATALOG_NAME}/utility/basic-auth/spoon/spoon`

RESPONSE_JSON=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_JSON == null ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}"
 echo 'Failed call with error' $RESPONSE
elif [[ $RESPONSE_JSON == '' ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}"
 echo 'Failed call with error' $RESPONSE 
else
  echo "${GREEN}SUCCESS${END_COLOR}"
  echo 'Sucessfully retrieved item ' $RESPONSE
fi

# ******************** Step 3. Get OAuth Access Token ********************
nice_echo "Step 3. Get OAuth Access Token"

CURL_BODY='a=b&client_id='${CONSUMER_CLIENT_ID}'&client_secret='${CONSUMER_CLIENT_SECRET}'&grant_type=password&scope='${CONSUMER_SCOPE}'&username='$CONSUMER_USERNAME'&password='${CONSUMER_PASSWORD}

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/x-www-form-urlencoded" --data "'"$CURL_BODY"'" ${DP_APIGW_ENDPOINT}/${pORG_NAME}/${CATALOG_NAME}/oauth2/token`

TOKEN_RESPONSE=`echo "$RESPONSE" | jq -r '.access_token'`

if [[ $TOKEN_RESPONSE == null ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}"
 echo 'Failed call with error' $RESPONSE 
elif [[ $TOKEN_RESPONSE == '' ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}"
 echo 'Failed call with error' $RESPONSE 
else
 echo "${GREEN}SUCCESS${END_COLOR}"
 echo 'Successfull login and obtained token ' $TOKEN_RESPONSE
fi

# ******************** Step 4. Invoke API with Access Token ********************
nice_echo "Step 4. Invoke API with Access Token"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${DP_APIGW_ENDPOINT}/${pORG_NAME}/${CATALOG_NAME}/api/current?zipcode=10510`

RESPONSE_JSON=`echo "$RESPONSE" | jq -r '.'`

if [[ $RESPONSE_JSON == null ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}"
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo "${GREEN}SUCCESS${END_COLOR}"
  echo 'Sucessfully retrieved item ' $RESPONSE_JSON
fi