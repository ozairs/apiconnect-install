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

# ******************** Step 1. Login as Admin and Get Token ********************
nice_echo "Step 1. Login as Admin and Get Token"

CURL_BODY='{"username":"'"${ADMIN_USERNAME}"'","password":"'"${ADMIN_PWD}"'","realm":"admin/default-idp-1","client_id":"'"${APIM_CLIENT_ID}"'","client_secret":"'"${APIM_CLIENT_SECRET}"'","grant_type":"password"}'

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -d "$CURL_BODY" ${APIM_SERVER}/api/token`

TOKEN_RESPONSE=`echo "$RESPONSE" | jq -r '.access_token'`

if [[ $TOKEN_RESPONSE == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE 
else
 # uncomment to display token
 echo 'Successfull login and obtained token ' #$TOKEN_RESPONSE
fi

echo    
read -p "Do you want to create a provider org from an new user (y), or create a provider org from an existing user (n). Answer with y or n." -n 1 -r
echo    
if [[ $REPLY =~ ^[Yy]$ ]]
then
	echo
	nice_echo "Creating a provider org from an new user"
	echo

	# ******************** Step 2. Invite a pOrg Owner ********************
	nice_echo "Step 2. Invite a pOrg Owner"

	CURL_BODY='{"email":"'"${pORG_EMAIL}"'","notify":true}'

	RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/cloud/org-invitations` 

	ACTIVATION_URL=`echo "$RESPONSE" | jq '.url' | tr -d '"'`
	ACTIVATION_LINK=`echo "$RESPONSE" | jq '.activation_link'`
	ACTIVATION_LINK_INDEX=`echo "$ACTIVATION_LINK" | jq -c 'index("activation=")'`
	ACTIVATION=`echo "$ACTIVATION_LINK" | jq -c '.['$ACTIVATION_LINK_INDEX':]' | jq -c '.[11:]' | tr -d '"' | base64 --decode`
	echo 'Activation URL' $ACTIVATION_URL

	if [[ $ACTIVATION_URL == null ]];   #call failed
	then
	echo 'Failed call with error' $RESPONSE 
	else
	echo 'Successfully invited pOrg owner with link' $ACTIVATION
	fi

	# ******************** Step 3. Register as pOrg Owner ********************
	nice_echo "Step 3. Register as pOrg Owner"

	CURL_BODY='{
		"user": {
			"realm": "provider/default-idp-2",
			"username": "'"${pORG_USERNAME}"'",
			"email": "'"${pORG_EMAIL}"'",
			"first_name": "'"${pORG_FIRST_NAME}"'",
			"last_name": "'"${pORG_LAST_NAME}"'",
			"password": "'"${pORG_PASSWORD}"'"
		},
		"org": {
			"name": "'"${pORG_NAME}"'",
			"title": "'"${pORG_NAME}"'"
		}
	}'

	RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $ACTIVATION" -d "$CURL_BODY" $ACTIVATION_URL'/register?client_id='${APIM_CLIENT_ID}'&client_secret='${APIM_CLIENT_SECRET}`

	RESPONSE_URL=`echo "$RESPONSE" | jq '.member.url'`

	if [[ $RESPONSE_URL == null ]];   #call failed
	then
	echo 'Failed call with error' $RESPONSE 
	exit
	else
	echo 'Successfully registered pOrg owner ' $RESPONSE_URL
	fi

	# ******************** Step 4. Login as the pOrg Owner and get token ********************
	nice_echo "Step 4. Login as the pOrg Owner and get token"

	CURL_BODY='{"username":"'"${pORG_USERNAME}"'","password":"'"${pORG_PASSWORD}"'","realm":"provider/default-idp-2","client_id":"'"${APIM_CLIENT_ID}"'","client_secret":"'"${APIM_CLIENT_SECRET}"'","grant_type":"password"}'

	RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $ACTIVATION" -d "$CURL_BODY" ${APIM_SERVER}/api/token`

	TOKEN_RESPONSE=`echo "$RESPONSE" | jq -r '.access_token'`

	if [[ $TOKEN_RESPONSE == null ]];   #call failed
	then
	echo 'Failed call with error' $RESPONSE 
	else
	echo 'Successfully login and obtained token ' $TOKEN_RESPONSE
	#exit 
	fi

else 

	echo
	nice_echo "Creating a provider org from an existing user"
	echo

	# ******************** Step 2. Get Local User Registry ********************
	nice_echo "Step 2. Get Local User Registry"

	RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/cloud/settings/user-registries` 

	RESPONSE_URL=`echo "$RESPONSE" | jq -r '.provider_user_registry_default_url'`

	if [[ $RESPONSE_URL == null ]];   #call failed
	then
	echo 'Failed call with error' $RESPONSE
	exit
	else
	echo 'Item retrieved ' $RESPONSE_URL
	fi

	# ******************** Step 3. Get existing User for new pOrg ********************
	nice_echo "Step 3. Get existing User for new pOrg "

	CURL_BODY='{"username":"'"${pORG_USERNAME}"'","remote":false}'

	RESPONSE=`curl -s X POST -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${RESPONSE_URL}/search` 

	RESPONSE_URL=`echo "$RESPONSE" | jq -r '.results[0].url'`

	if [[ $RESPONSE_URL == null ]];   #call failed
	then
	echo 'Failed call with error' $RESPONSE
	exit
	else
	echo 'Item retrieved ' $RESPONSE_URL
	fi

	# ******************** Step 4. Create pOrg ********************
	nice_echo "Step 4. Create pOrg "

	CURL_BODY='{"title":"'"${pORG_NAME}"'","name":"'"${pORG_NAME}"'","owner_url":"'"${RESPONSE_URL}"'"}'
	
	RESPONSE=`curl -s -k -X POST -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/cloud/orgs`

	RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

	if [[ $RESPONSE_URL == null ]];   #call failed
	then
	echo 'Failed call with error' $RESPONSE
	#exit
	else
	echo 'Create pOrg with URL ' $RESPONSE_URL
	fi

	# ******************** Step 5. Login as the pOrg Owner and get token ********************
	nice_echo "Step 5. Login as the pOrg Owner and get token"

	CURL_BODY='{"username":"'"${pORG_USERNAME}"'","password":"'"${pORG_PASSWORD}"'","realm":"provider/default-idp-2","client_id":"'"${APIM_CLIENT_ID}"'","client_secret":"'"${APIM_CLIENT_SECRET}"'","grant_type":"password"}'

	RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -d "$CURL_BODY" ${APIM_SERVER}/api/token`

	TOKEN_RESPONSE=`echo "$RESPONSE" | jq -r '.access_token'`

	if [[ $TOKEN_RESPONSE == null ]];   #call failed
	then
	echo 'Failed call with error' $RESPONSE 
	else
	echo 'Successfully login and obtained token ' $TOKEN_RESPONSE
	#exit 
	fi

fi

echo    
read -p "Do you want to configure the portal for the catalog ${CATALOG_NAME} (y/n)." -n 1 -r
echo    
if [[ $REPLY =~ ^[Yy]$ ]]
then

	# ******************** Step 5. Obtain portal settings ********************
	nice_echo "Step 5. Obtain portal settings"

	RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE"  ${APIM_SERVER}/api/orgs/om/portal-services/portal-service`

	RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

	if [[ $RESPONSE_URL == null ]];   #call failed
	then
	echo 'Failed call with error' $RESPONSE 
	else
	echo 'Successfully login and obtained settings with URL ' $RESPONSE_URL
	#exit 
	fi

	# ******************** Step 6. Configure portal settings ********************
	nice_echo "Step 6. Configure portal settings"

	CURL_BODY='{
		"portal": {
			"portal_service_url": "'"${RESPONSE_URL}"'",
			"type": "drupal"
		}}'

	RESPONSE=`curl -s -k -X PUT -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/catalogs/${pORG_NAME}/${CATALOG_NAME}/settings`

	RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

	if [[ $RESPONSE_URL == null ]];   #call failed
	then
	echo 'Failed call with error' $RESPONSE
	#exit
	else
	echo 'Configured portal for catalog ' $RESPONSE_URL
	fi
fi

#nice_echo "Script actions completed. Check logs for more details."