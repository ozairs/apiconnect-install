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
 echo 'Failed call with error' $RESPONSE 
else
 echo "${GREEN}SUCCESS${END_COLOR}" 
 echo 'Successfully login and obtained token ' #$TOKEN_RESPONSE
fi

echo    
read -p "Enter the User Registry type you would like to create (1/2) (1 - Authentication URL / 2 - LDAP)." -n 1 -r
echo    
# authentication URL
if [ $REPLY == 1 ]; then
  USER_REGISTRY_TYPE='authurl'
  USER_REGISTRY_REQ=''
  echo '> Selected User Registry type Authentication URL User Registry.'
# ldap
elif [ $REPLY == 2 ]; then
  USER_REGISTRY_TYPE='ldap'
  USER_REGISTRY_REQ='
    "configuration": {
        "authentication_method": "'"${USER_REGISTRY_LDAP_AU_METHOD}"'",
        "authenticated_bind": "'"${USER_REGISTRY_LDAP_AU_BIND}"'",
        "search_dn_base": "'"${USER_REGISTRY_LDAP_DN_BASE}"'",
        "protocol_version": "'"${USER_REGISTRY_LDAP_VERSION}"'",
        "bind_prefix": "'"${USER_REGISTRY_LDAP_DN_BIND_PREFIX}"'",
        "bind_suffix": "'"$USER_REGISTRY_LDAP_DN_BIND_SUFFIX}"'",
        "admin_dn": "'"$USER_REGISTRY_LDAP_ADMIN_DN}"'",
        "admin_password": "'"$USER_REGISTRY_LDAP_ADMIN_PASSWORD}"'"
    },'
  echo '> Selected User Registry type LDAP User Registry.'
# bad registry type
else
  USER_REGISTRY_TYPE='NA'
  echo '> Incorrect User Registry type selected.'
fi

# ******************** Step 2. Get User Registry Integration URL ********************
nice_echo "Step 2. Get User Registry Authentication URL"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/cloud/integrations/user-registry/$USER_REGISTRY_TYPE`

INTEGRATION_URL=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}"
 echo 'Failed call with error' $RESPONSE
else
  echo "${GREEN}SUCCESS${END_COLOR}"  
  echo 'Sucessfully retrieved item ' $INTEGRATION_URL
fi

# ******************** Step 3. TLS Profile ********************
nice_echo "Step 3. TLS Profile"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/orgs/${pORG_NAME}/tls-client-profiles`

TLS_PROFILE_RESPONSE_URL=`echo "$RESPONSE" | jq -r '.results[] | select(.name =="tls-client-profile-default").url'`

if [[ $TLS_PROFILE_RESPONSE_URL == null ]];   #call failed
then
  echo "${RED}FAIL${END_COLOR}" 
  echo 'Failed call with error' $RESPONSE
  exit
else
  echo "${GREEN}SUCCESS${END_COLOR}"   
  echo 'Sucessfully retrieved item ' $TLS_PROFILE_RESPONSE_URL
fi

# ******************** Step 4. Configure TLS Profile in Sandbox Catalog ********************
nice_echo "Step 4. Configure TLS Profile in Sandbox Catalog"

CURL_BODY='{
    "tls_client_profile_url": "'"${TLS_PROFILE_RESPONSE_URL}"'"
}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/catalogs/${pORG_NAME}/${CATALOG_NAME}/configured-tls-client-profiles`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`
RESPONSE_CODE=`echo "$RESPONSE" | jq -r '.status'`

if [[ $RESPONSE_CODE == 409 ]];   #item exists 
then
  TLS_CLIENT_PROFILE_ID=`echo "$RESPONSE" | jq -r '.message' | sed -e 's/\(^.*id:[[:space:]]*\)\(.*\)\(already.*$\)/\2/' | tr ')' ' ' | tr '[' ' ' | tr ']' ' ' | tr -d ' ' | xargs` 
  RESPONSE_URL=${APIM_SERVER}/api/orgs/${pORG_NAME}/tls-client-profiles/$TLS_CLIENT_PROFILE_ID
  echo "${GREEN}SUCCESS${END_COLOR}"   
  echo "TLS Profile already exists, sucessfully retrieved item" $RESPONSE_URL
elif [[ $RESPONSE_URL == null ]];   #call failed
then
 echo "${RED}FAIL${END_COLOR}" 
 echo 'Failed call with error' $RESPONSE
else
  echo "${GREEN}SUCCESS${END_COLOR}"   
  echo 'Sucessfully created item ' $RESPONSE_URL
fi

# ******************** Step 5. Create User Registry ********************
nice_echo "Step 5. Create User Registry"

# Append TLS client profile
USER_REGISTRY_BODY=`echo '"endpoint": {"endpoint": "'"${USER_REGISTRY_URL}"'","tls_client_profile_url": "'"${TLS_PROFILE_RESPONSE_URL}"'"},'$USER_REGISTRY_REQ`

CURL_BODY=`echo '{
    "title": "'"${USER_REGISTRY}"'",
    "name": "'"${USER_REGISTRY}"'",
    "case_sensitive": false,
    "registry_type" : "'"${USER_REGISTRY_TYPE}"'",
    "identity_providers": [
        {
            "title": "'"${USER_REGISTRY}"'",
            "name": "'"${USER_REGISTRY}"'"
        }
    ],' $USER_REGISTRY_BODY '"integration_url": "'"${INTEGRATION_URL}"'"}'`

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/orgs/${pORG_NAME}/user-registries`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`
RESPONSE_CODE=`echo "$RESPONSE" | jq -r '.status'`

if [[ $RESPONSE_CODE == 409 ]];   #since item exists, update any new info
then
  echo "User Registry already exists, performing update now ..." $RESPONSE
  
  USER_REGISTRY_ID=`echo "$RESPONSE" | jq -r '.message' | sed -e 's/\(^.*id:[[:space:]]*\)\(.*\)\(already.*$\)/\2/' | tr ')' ' ' | tr '[' ' ' | tr ']' ' ' | tr -d ' ' | xargs` 

  #echo "USER REGISTRY ID" $USER_REGISTRY_ID
  #echo "URL" ${APIM_SERVER}/api/user-registries/${pORG_NAME}/$USER_REGISTRY_ID
  
  RESPONSE=`curl -s -k -X PATCH -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d '{ "title": "'"${USER_REGISTRY}"'", "name": "'"${USER_REGISTRY}"'","endpoint": {"endpoint": "'"${USER_REGISTRY_URL}"'","tls_client_profile_url": "'"${TLS_PROFILE_RESPONSE_URL}"'"},"identity_providers": [{"title": "'"${USER_REGISTRY}"'","name": "'"${USER_REGISTRY}"'"}]}' ${APIM_SERVER}/api/user-registries/${pORG_NAME}/$USER_REGISTRY_ID`

  RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

  if [[ $RESPONSE_URL == null ]];   
  then
    echo "${RED}FAIL${END_COLOR}" 
    echo 'Failed call with error' $RESPONSE
  else
    echo "${GREEN}SUCCESS${END_COLOR}"   
    echo 'Sucessfully updated item ' $RESPONSE_URL
  fi

elif [[ $RESPONSE_URL == null ]];   
then
  echo "${RED}FAIL${END_COLOR}" 
  echo 'Failed call with error' $RESPONSE
else
  echo "${GREEN}SUCCESS${END_COLOR}"   
  echo 'Sucessfully created item ' $RESPONSE_URL
fi

# ******************** Step 6. Configure User Registry in Sandbox Catalog ********************
nice_echo "Step 6. Configure User Registry in Sandbox Catalog"

CURL_BODY='{
    "user_registry_url": "'"${RESPONSE_URL}"'"
}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/catalogs/${pORG_NAME}/${CATALOG_NAME}/configured-api-user-registries`

RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

if [[ $RESPONSE_URL == null ]];   #call failed
then
  echo "${RED}FAIL${END_COLOR}" 
  echo 'Failed call with error' $RESPONSE
else
  echo "${GREEN}SUCCESS${END_COLOR}"   
  echo 'Sucessfully created item ' $RESPONSE_URL
fi

# ******************** Step 7. Create OAuth Provider URL ********************
nice_echo "Step 7. Create OAuth Provider"

OAUTH_PROVIDER=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" $OAUTH_PROVIDER_URL > oauth-provider-tmp.cfg`

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d @oauth-provider-tmp.cfg ${APIM_SERVER}/api/orgs/${pORG_NAME}/oauth-providers`

RESPONSE_URL=`echo "$RESPONSE" | tr '\r\n' ' ' | jq -r '.url'`
RESPONSE_CODE=`echo "$RESPONSE" | jq -r '.status'`

if [[ $RESPONSE_CODE == 409 ]];   #since item exists, update any new info
then
  echo "OAuth Provider already exists." $RESPONSE

  OAUTH_PROVIDER_ID=`echo "$RESPONSE" | jq -r '.message' | sed -e 's/\(^.*id:[[:space:]]*\)\(.*\)\(already.*$\)/\2/' | tr ')' ' ' | tr '[' ' ' | tr ']' ' ' | tr -d ' ' | xargs` 

  #echo "OAUTH_PROVIDER_ID" $OAUTH_PROVIDER_ID
  #echo "URL" ${APIM_SERVER}/api/orgs/${pORG_NAME}/oauth-providers/$OAUTH_PROVIDER_ID
  
  RESPONSE=`curl -s -k -X PATCH -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d @oauth-provider-tmp.cfg ${APIM_SERVER}/api/orgs/${pORG_NAME}/oauth-providers/$OAUTH_PROVIDER_ID`

  RESPONSE_URL=`echo "$RESPONSE" | tr '\r\n' ' ' | jq -r '.url'`

  if [[ $RESPONSE_URL == null ]];   
  then
    echo "${RED}FAIL${END_COLOR}" 
    echo 'Failed call with error' $RESPONSE
  else
    echo "${GREEN}SUCCESS${END_COLOR}"   
    echo 'Sucessfully updated item ' $RESPONSE_URL
  fi

elif [[ $RESPONSE_URL == null ]];   #call failed
then
  echo "${RED}FAIL${END_COLOR}" 
  echo 'Failed call with error' $RESPONSE
else
  echo "${GREEN}SUCCESS${END_COLOR}"   
  echo 'Sucessfully created item ' $RESPONSE_URL
fi

#remove temporary file
rm oauth-provider-tmp.cfg

# ******************** Step 8. Configure OAuth Provider in Sandbox Catalog ********************
nice_echo "Step 8. Configure OAuth Provider in Sandbox Catalog"

CURL_BODY='{
    "oauth_provider_url": "'"${RESPONSE_URL}"'"
}'

RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/catalogs/${pORG_NAME}/${CATALOG_NAME}/configured-oauth-providers`

RESPONSE_URL=`echo "$RESPONSE" | tr '\r\n' ' ' | jq -r '.url'`
RESPONSE_CODE=`echo "$RESPONSE" | jq -r '.status'`


if [[ $RESPONSE_CODE == 409 ]];   
then
  echo "${GREEN}SUCCESS${END_COLOR}"   
  echo "OAuth Provider already exists in" ${CATALOG_NAME} "catalog and does not need to be updated." $RESPONSE
elif [[ $RESPONSE_URL == null ]];   #call failed
then
  echo "${RED}FAIL${END_COLOR}" 
  echo 'Failed call with error' $RESPONSE
else
  echo "${GREEN}SUCCESS${END_COLOR}"   
  echo 'Sucessfully created item ' $RESPONSE_URL
fi