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

nice_echo "Step 1. Login as Admin and Get Token"

CURL_BODY='{"username":"admin","password":"'"${PWD}"'","realm":"admin/default-idp-1","client_id":"caa87d9a-8cd7-4686-8b6e-ee2cdc5ee267","client_secret":"3ecff363-7eb3-44be-9e07-6d4386c48b0b","grant_type":"password"}'

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -d "$CURL_BODY" ${APIM_SERVER}/api/token`

TOKEN_RESPONSE=`echo "$RESPONSE" | jq -r '.access_token'`

if [[ $TOKEN_RESPONSE == null ]];   #call failed
then
 echo 'Failed to get access token from API management subsystem with error' $RESPONSE
 exit
else
  echo 'Item retrieved ' $TOKEN_RESPONSE
fi

nice_echo "Step 2. Get Default TLS Client profiles"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/orgs/admin/tls-client-profiles/tls-client-profile-default` 

TLS_CLIENT_RESPONSE_URL=`echo "$RESPONSE" | jq -r '.results[0].url'`

if [[ $CLIENT_RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 exit
else
  echo 'Item retrieved ' $TLS_CLIENT_RESPONSE_URL
fi

nice_echo "Step 3. Get Default TLS Server profiles"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/orgs/admin/tls-server-profiles/tls-server-profile-default` 

TLS_SERVER_RESPONSE_URL=`echo "$RESPONSE" | jq -r '.results[0].url'`

if [[ $TLS_SERVER_RESPONSE_URL == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 exit
else
  echo 'Item retrieved ' $TLS_SERVER_RESPONSE_URL
fi

echo    # (optional) move to a new line
read -p "Do you want to configure an email server (y/n)." -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  nice_echo "Step 4. Create a email server resource"

  CURL_BODY='{"title":"Sendgrid","name":"sendgrid","host":"smtp.sendgrid.net","port":587,"credentials":{"username":"'"${EMAIL_USERNAME}"'","password":"'"${EMAIL_PASSWORD}"'"},"tls_client_profile_url":"'"$TLS_CLIENT_RESPONSE_URL"'"}'

  RESPONSE=`curl-s  -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/orgs/admin/mail-servers`

  RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

  if [[ $RESPONSE_URL == null ]];   #call failed
  then
  echo 'Failed call with error' $RESPONSE
  #exit
  else
    echo 'Item retrieved ' $RESPONSE_URL
  fi

  nice_echo "Step 5. Configure email server in cloud settings"

  CURL_BODY='{"mail_server_url": "'"${RESPONSE_URL}"'", "email_sender": {"name": "APIC Administrator","address": "ibmapic+admin@gmail.com"}}'

  RESPONSE=`curl -s -k -X PUT -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/cloud/settings`

  RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

  if [[ $RESPONSE_URL == null ]];   #call failed
  then
  echo 'Failed call with error' $RESPONSE
  #exit
  else
    echo 'Item retrieved ' $RESPONSE_URL
  fi
fi

read -p "Do you want to register the gateway subsystem (y/n)." -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  nice_echo "Step 6. Get DataPower Gateway Integration type"

  RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/cloud/integrations/gateway-service/datapower-api-gateway` 

  RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

  if [[ $RESPONSE_URL == null ]];   #call failed
  then
  echo 'Failed call with error' $RESPONSE
  exit
  else
    echo 'Item retrieved ' $RESPONSE_URL
  fi

  nice_echo "Step 7. Register DataPower API Gateway"

  CURL_BODY='{"name": "datapower-api-gateway-service","title": "Datapower API Gateway Service","summary": "Datapower API Gateway Service","endpoint": "'"${DP_APIGW_ENDPOINT}"'","api_endpoint_base":"'"${DP_APIGW_MANAGEMENT_ENDPOINT}"'","tls_client_profile_url": "'"$TLS_CLIENT_RESPONSE_URL"'","gateway_service_type":"datapower-api-gateway","visibility": {"type": "public"},"sni": [{"host": "*","tls_server_profile_url": "'"$TLS_SERVER_RESPONSE_URL"'"}],"integration_url": "'"$RESPONSE_URL"'"}'

  RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/orgs/admin/availability-zones/availability-zone-default/gateway-services`

  RESPONSE_URL=`echo "$RESPONSE" | jq '.url'`

  if [[ $RESPONSE_URL == null ]];   #call failed
  then
  echo 'Failed call with error' $RESPONSE
  else
  echo 'API Gateway successfully registered at endpoint ' $DP_APIGW_ENDPOINT
  #exit 
  fi

  nice_echo "Step 8. Set Default Gateway to the Sandbox Catalog - Use Datapower API Gateway Service"

  CURL_BODY='{"gateway_service_default_urls":['"${RESPONSE_URL}"']}'

  RESPONSE=`curl -s -k -X PUT -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/cloud/settings`

  RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

  if [[ $RESPONSE_URL == null ]];   #call failed
  then
  echo 'Failed call with error' $RESPONSE
  #exit
  else
    echo 'Sucessfully set default gateway for Sandbox catalog ' $RESPONSE_URL
  fi
fi

read -p "Do you want to register the portal subsystem (y/n)." -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
  nice_echo "Step 9. Get default Portal TLS Client profile"

  RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/orgs/admin/tls-client-profiles/portal-api-admin-default` 

  RESPONSE_URL=`echo "$RESPONSE" | jq -r '.results[0].url'`

  if [[ $RESPONSE_URL == null ]];   #call failed
  then
  echo 'Failed call with error' $RESPONSE
  exit
  else
    echo 'Item retrieved ' $RESPONSE_URL
  fi

  nice_echo "Step 10. Register Portal"

  CURL_BODY='{
    "title": "Portal Service",
    "name": "portal-service",
    "summary": "Portal Service",
    "endpoint": "'"${PORTAL_MANAGEMENT_ENDPOINT}"'",
    "web_endpoint_base": "'"${PORTAL_WEB_ENDPOINT}"'",
          "endpoint_tls_client_profile_url": "'"$RESPONSE_URL"'",
    "visibility": {
      "type": "public"
    }
  }'

  RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/orgs/admin/availability-zones/availability-zone-default/portal-services`

  RESPONSE_URL=`echo "$RESPONSE" | jq '.url'`

  if [[ $RESPONSE_URL == null ]];   #call failed
  then
  echo 'Failed call with error' $RESPONSE 
  else
  echo 'Portal successfully registered at endpoint ' ${PORTAL_WEB_ENDPOINT}
  #exit 
  fi

fi

read -p "Do you want to register the analytics subsystem (y/n)." -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then

  nice_echo "Step 11. Get default Analytics Client TLS profile"

  RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/orgs/admin/tls-client-profiles/analytics-client-default` 

  RESPONSE_URL_AC=`echo "$RESPONSE" | jq -r '.results[0].url'`

  if [[ $RESPONSE_URL_AC == null ]];   #call failed
  then
  echo 'Failed call with error' $RESPONSE
  exit
  else
    echo 'Item retrieved ' $RESPONSE_URL_AC
  fi

  nice_echo "Step 12. Get default Analytics Ingestion TLS profile"

  RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" ${APIM_SERVER}/api/orgs/admin/tls-client-profiles/analytics-ingestion-default` 

  RESPONSE_URL_AI=`echo "$RESPONSE" | jq -r '.results[0].url'`

  if [[ $RESPONSE_URL_AI == null ]];   #call failed
  then
  echo 'Failed call with error' $RESPONSE
  #exit
  else
    echo 'Item retrieved ' $RESPONSE_URL_AI
  fi

  nice_echo "Step 13. Register Analytics"

  CURL_BODY='{
    "title": "Analytics Service",
    "name": "analytics-service",
    "summary": "Analytics Service",
    "endpoint": "'"${ANALYTICS_MANAGEMENT_ENDPOINT}"'",
          "client_endpoint_tls_client_profile_url": "'"$RESPONSE_URL_AC"'",
          "ingestion_endpoint_tls_client_profile_url": "'"$RESPONSE_URL_AI"'"
  }'

  RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/orgs/admin/availability-zones/availability-zone-default/analytics-services`

  RESPONSE_URL=`echo "$RESPONSE" | jq '.url'`

  if [[ $RESPONSE_URL == null ]];   #call failed
  then
  echo 'Failed call with error' $RESPONSE
  exit 
  else
  echo 'Analytics successfully registered at endpoint ' ${ANALYTICS_MANAGEMENT_ENDPOINT}
  fi

  nice_echo "Step 14. Associate analytics to DataPower Gateway"

  CURL_BODY='{"analytics_service_url":'$RESPONSE_URL'}'

  RESPONSE=`curl -k -X PATCH -H "Content-Type: application/json" -H "Accept: application/json" -H "Authorization: Bearer $TOKEN_RESPONSE" -d "$CURL_BODY" ${APIM_SERVER}/api/orgs/admin/availability-zones/availability-zone-default/gateway-services/datapower-api-gateway-service` 

  RESPONSE_URL=`echo "$RESPONSE" | jq -r '.url'`

  if [[ $RESPONSE_URL == null ]];   #call failed
  then
  echo 'Failed call with error' $RESPONSE
  exit
  else
    echo 'Succesesfully associated analytics to DataPower Gateway ' $RESPONSE_URL
  fi
fi

nice_echo "Script actions completed. Check logs for more details."