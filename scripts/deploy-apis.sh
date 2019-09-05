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

# ******************** Step 9. Obtain API document #1 ********************
nice_echo "Step 9. Obtain API document #1"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json"  $API_DEFINITION_URL`

if [[ $RESPONSE == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully retrieved API.'
fi


# ******************** Step 10. Create API #1 ********************
nice_echo "Step 10. Create API #1"

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

# ******************** Step 11. Obtain API document #1 ********************
nice_echo "Step 11. Obtain API document #2"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json"  $API_DEFINITION_URL2`

if [[ $RESPONSE == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully retrieved API.'
fi


# ******************** Step 12. Create API #2 ********************
nice_echo "Step 12. Create API #2"

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

# ******************** Step 13. Obtain API product ********************
nice_echo "Step 13. Obtain API product"

RESPONSE=`curl -s -k -H "Content-Type: application/json" -H "Accept: application/json" $API_PRODUCT_DEFINITION_URL`

if [[ $RESPONSE == null ]];   #call failed
then
 echo 'Failed call with error' $RESPONSE
 #exit
else
  echo 'Sucessfully retrieved API.'
fi

# ******************** Step 14. Create API Product ********************
nice_echo "Step 14. Create API Product"

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

# ******************** Step 15. Publish API Product ********************
nice_echo "Step 15. Publish API Product"

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