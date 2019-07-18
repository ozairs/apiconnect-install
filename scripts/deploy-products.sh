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
else
 echo 'Successfully login and obtained token ' #$TOKEN_RESPONSE
fi

# ******************** Step 2. Get User Registry Integration URL ********************
nice_echo "Step 2. Get User Registry Authentication URL"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/cloud/integrations/user-registry/authurl`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully retrieved item ' $RESPONSE_URL
fi

# ******************** Step 3. TLS Profile ********************
nice_echo "Step 3. TLS Profile"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/orgs/${pORG_NAME}/tls-client-profiles`

TLS_PROFILE_RESPONSE_URL=`echo "$RESPONSE" | jq -r '.results[] | select(.name =="tls-client-profile-default").url'`

if [[ $TLS_PROFILE_RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully retrieved item ' $TLS_PROFILE_RESPONSE_URL
fi

# ******************** Step 4. Create Authentication URL ********************
nice_echo "Step 4. Create Authentication URL"

CURL_BODY='{
    "registry_type": "authurl",
    "title": "'"${USER_REGISTRY}"'",
    "name": "'"${USER_REGISTRY}"'",
    "endpoint": {
        "endpoint": "'"${USER_REGISTRY_URL}"'",
        "tls_client_profile_url": "'"${TLS_PROFILE_RESPONSE_URL}"'"
    },
    "case_sensitive": false,
    "identity_providers": [
        {
            "title": "'"${USER_REGISTRY}"'",
            "name": "'"${USER_REGISTRY}"'"
        }
    ],
    "integration_url": "'"${RESPONSE_URL}"'"
}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/orgs/${pORG_NAME}/user-registries`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully creates item ' $RESPONSE_URL
fi

# ******************** Step 5. Configure User Registry in Sandbox Catalog ********************
nice_echo "Step 5. Configure User Registry in Sandbox Catalog"

CURL_BODY='{
    "user_registry_url": "'"${RESPONSE_URL}"'"
}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/catalogs/${pORG_NAME}/${CATALOG_NAME}/configured-api-user-registries`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully created item ' $RESPONSE_URL
fi

# ******************** Step 6. Create OAuth Provider URL ********************
nice_echo "Step 6. Create OAuth Provider"

OAUTH_PROVIDER=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" $OAUTH_PROVIDER_URL > oauth-provider-tmp.cfg`

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d @oauth-provider-tmp.cfg ${APIM_SERVER}/api/orgs/${pORG_NAME}/oauth-providers`

RESPONSE_URL=`echo "$RESPONSE" | tr '\r\n' ' ' | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully created item ' $RESPONSE_URL
fi

#remove temporary file
rm oauth-provider-tmp.cfg

# ******************** Step 7. Configure OAuth Provider in Sandbox Catalog ********************
nice_echo "Step 7. Configure OAuth Provider in Sandbox Catalog"

CURL_BODY='{
    "oauth_provider_url": "'"${RESPONSE_URL}"'"
}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/catalogs/${pORG_NAME}/${CATALOG_NAME}/configured-oauth-providers`

RESPONSE_URL=`echo "$RESPONSE" | tr '\r\n' ' ' | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully created item ' $RESPONSE_URL
fi

# ******************** Step 8. Obtain API document #1 ********************
nice_echo "Step 8. Obtain API document #1"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json"  $API_DEFINITION_URL`

if [[ $RESPONSE == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully retrieved API.'
fi


# ******************** Step 9. Create API #1 ********************
nice_echo "Step 9. Create API #1"

CURL_BODY='{"type":"draft_api","draft_api":'${RESPONSE}'}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/orgs/${pORG_NAME}/drafts/draft-apis --silent`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully created API in Drafts ' $RESPONSE_URL
fi

# ******************** Step 10. Obtain API document #1 ********************
nice_echo "Step 10. Obtain API document #2"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json"  $API_DEFINITION_URL2`

if [[ $RESPONSE == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully retrieved API.'
fi


# ******************** Step 11. Create API #2 ********************
nice_echo "Step 11. Create API #2"

CURL_BODY='{"type":"draft_api","draft_api":'${RESPONSE}'}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/orgs/${pORG_NAME}/drafts/draft-apis --silent`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully created API in Drafts ' $RESPONSE_URL
fi

# ******************** Step 12. Obtain API product ********************
nice_echo "Step 12. Obtain API product"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" $API_PRODUCT_DEFINITION_URL`

if [[ $RESPONSE == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully retrieved API.'
fi

# ******************** Step 13. Create API Product ********************
nice_echo "Step 13. Create API Product"

CURL_BODY='{"type":"draft_product","draft_product":'${RESPONSE}'}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/orgs/${pORG_NAME}/drafts/draft-products`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully created API product in Drafts ' $RESPONSE_URL
fi

# ******************** Step 14. Publish API Product ********************
nice_echo "Step 14. Publish API Product"

CURL_BODY='{"draft_product_url":"'"${RESPONSE_URL}"'"}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/catalogs/${pORG_NAME}/sandbox/publish-draft-product`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully published API product in Drafts ' $RESPONSE_URL
fi

nice_echo "Script actions completed. Check logs for more details."