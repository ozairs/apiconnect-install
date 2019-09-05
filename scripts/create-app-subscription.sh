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

# ******************** Step 1. Login as the pOrg Owner and get token ********************
nice_echo "Step 1. Login as the pOrg Owner and get token"

CURL_BODY='{"username":"'"${pORG_USERNAME}"'","password":"'"${pORG_PASSWORD}"'","realm":"provider/default-idp-2","client_id":"'"${APIM_CLIENT_ID}"'","client_secret":"'"${APIM_CLIENT_SECRET}"'","grant_type":"password"}'

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $ACTIVATION" -d "$CURL_BODY" ${APIM_SERVER}/api/token`

TOKEN_RESPONSE=`echo "$RESPONSE" | jq -r '.access_token'`

if [[ $TOKEN_RESPONSE == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE 
elif [[ $TOKEN_RESPONSE == '' ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE 
else
 echo 'Successfully login and obtained token ' #$TOKEN_RESPONSE
fi

# ******************** Step 2. Get Consumer Org ********************
nice_echo "Step 2. Get Consumer Org"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/consumer-orgs/${pORG_NAME}/${CATALOG_NAME}/${CONSUMER_ORG}`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully retrieved item ' $RESPONSE_URL
fi

# ******************** Step 3. Get Application ********************
nice_echo "Step 3. Get Application"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/consumer-orgs/${pORG_NAME}/${CATALOG_NAME}/${CONSUMER_ORG}/apps`

RESPONSE_URL=`echo "$RESPONSE" | tr '\r\n' ' ' | jq -r '.results[0].url'`
RESPONSE_URL1=`basename "$RESPONSE_URL"`
RESPONSE_URL2=`dirname "$RESPONSE_URL" | xargs basename`

if [[ $RESPONSE_URL1 == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully retrieved item ' $RESPONSE_URL
fi

# ******************** Step 4. Create Application Credentials ********************
nice_echo "Step 4. Create Application Credentials"

CURL_BODY='{ "name": "'"${CONSUMER_APP_CREDS}"'"}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/apps/${pORG_NAME}/${CATALOG_NAME}/${RESPONSE_URL2}/${RESPONSE_URL1}/credentials`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo "Application credential created."
  CLIENT_ID=`echo "$RESPONSE" | jq -r '.client_id'`
  nice_echo "Client ID"
  echo ${CLIENT_ID}

  CLIENT_SECRET=`echo "$RESPONSE" | jq -r '.client_secret'`
  nice_echo "Client Secret" 
  echo ${CLIENT_SECRET}
fi

# ******************** Step 5. Modify Application  ********************
nice_echo "Step 5. Modify Application with Consumer Info"

CURL_BODY='{
    "title": "Sandbox Test App",
    "name": "sandbox-test-app",
    "summary": "Default Sandbox test application",
    "redirect_endpoints": [
        "'"${CONSUMER_REDIRECT_URL}"'"
    ],
    "application_public_certificate_entry": "'"-----BEGIN CERTIFICATE-----\n${CONSUMER_APP_CERT}\n-----END CERTIFICATE-----\n"'"
}'
#
RESPONSE=`curl -s -k -X PATCH -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/apps/${pORG_NAME}/${CATALOG_NAME}/${RESPONSE_URL2}/${RESPONSE_URL1}`

RESPONSE_URL=`echo "$RESPONSE" | tr '\r\n' ' ' | jq -r '.name'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully modified item ' $RESPONSE_URL
fi

# ******************** Step 6. Get API Product ********************
nice_echo "Step 6. Get API Product"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/orgs/${pORG_NAME}/drafts/draft-products`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.results[] | select(.name =="'"${API_PRODUCT_NAME}"'").url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully retrieved item ' $RESPONSE_URL
fi

# ******************** Step 7. Publish API Product ********************
nice_echo "Step 7. Publish API Product"

CURL_BODY='{"draft_product_url":"'"${RESPONSE_URL}"'"}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/catalogs/${pORG_NAME}/sandbox/publish-draft-product`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully published API product ' $RESPONSE_URL
fi

# ******************** Step 8. Create Application Subscription  ********************
nice_echo "Step 8. Create Application Subscription"

CURL_BODY='{"product_url":"'"${RESPONSE_URL}"'","plan":"default-plan"}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/apps/${pORG_NAME}/${CATALOG_NAME}/${RESPONSE_URL2}/${RESPONSE_URL1}/subscriptions`

RESPONSE_URL=`echo "$RESPONSE" | tr '\r\n' ' ' | jq -r '.name'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully modified item ' $RESPONSE_URL
fi

nice_echo "Script actions completed. Check logs for more details."
