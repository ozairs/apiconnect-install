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

# ******************** Step 1. Login as the pOrg Owner and get token ********************
nice_echo "Step 1. Login as the pOrg Owner and get token"

CURL_BODY='{"username":"'"${pORG_USERNAME}"'","password":"'"${pORG_PASSWORD}"'","realm":"provider/default-idp-2","client_id":"'"${APIM_CLIENT_ID}"'","client_secret":"'"${APIM_CLIENT_SECRET}"'","grant_type":"password"}'

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $ACTIVATION" -d "$CURL_BODY" ${APIM_SERVER}/api/token`

TOKEN_RESPONSE=`echo "$RESPONSE" | jq -r '.access_token'`

if [[ $TOKEN_RESPONSE == null ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}"
 echo 'Error' $RESPONSE 
elif [[ $TOKEN_RESPONSE == '' ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}"
 echo 'Error' $RESPONSE 
else
 echo "${GREEN}SUCCESS${END_COLOR}"
 echo 'Obtained token '
fi

# ******************** Step 2. Get Application ********************
nice_echo "Step 2. Get Application"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/consumer-orgs/${pORG_NAME}/${CATALOG_NAME}/${CONSUMER_ORG}/apps`

RESPONSE_URL=`echo "$RESPONSE" | tr '\r\n' ' ' | jq -r '.results[0].url'`
RESPONSE_URL1=`basename "$RESPONSE_URL"`
RESPONSE_URL2=`dirname "$RESPONSE_URL" | xargs basename`

if [[ $RESPONSE_URL1 == null ]];   #call failed
then
  echo "${RED}FAIL${END_COLOR}"
  echo 'Error' $RESPONSE
 #exit
else
  echo "${GREEN}SUCCESS${END_COLOR}"
  echo 'Retrieved item ' $RESPONSE_URL
fi

# ******************** Step 3. Get API Product ********************
nice_echo "Step 3. Get API Product"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/orgs/${pORG_NAME}/drafts/draft-products/${API_PRODUCT_NAME}`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.results[0].url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}"
 echo 'Error' $RESPONSE
 #exit
else
  echo "${GREEN}SUCCESS${END_COLOR}"
  echo 'Retrieved item ' $RESPONSE_URL
fi

# ******************** Step 4. Publish API Product ********************
nice_echo "Step 4. Publish API Product"

CURL_BODY='{"draft_product_url":"'"${RESPONSE_URL}"'"}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/catalogs/${pORG_NAME}/sandbox/publish-draft-product`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}"
 echo 'Error' $RESPONSE
 #exit
else
  echo "${GREEN}SUCCESS${END_COLOR}"
  echo 'Published API product in Drafts ' $RESPONSE_URL
fi

# ******************** Step 5. Create Application Subscription  ********************
nice_echo "Step 5. Create Application Subscription"

CURL_BODY='{"product_url":"'"${RESPONSE_URL}"'","plan":"default-plan"}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/apps/${pORG_NAME}/${CATALOG_NAME}/${RESPONSE_URL2}/${RESPONSE_URL1}/subscriptions`

RESPONSE_URL=`echo "$RESPONSE" | tr '\r\n' ' ' | jq -r '.name'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}"
 echo 'Error' $RESPONSE
 #exit
else
  echo "${GREEN}SUCCESS${END_COLOR}"
  echo 'Modified item ' $RESPONSE_URL
fi

nice_echo "Script actions completed. Check logs for more details."