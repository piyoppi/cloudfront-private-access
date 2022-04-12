#!/bin/sh

cd `dirname $0`

eval `cat ./.define.env`

if [ ! -e ../$ENVFILE ]; then
    echo '[ERROR] config file (bin/.env) is not found.'
    exit 255
fi

if [ ! -e ../$CONFIG_FILE ]; then
    echo '[ERROR] config file (config/config.json) is not found.'
    exit 255
fi

eval `cat ../$ENVFILE`

#
# build static html login page
# ----------------------------

AUTH_ISSUER_CLIENT_ID=`cat ../${CONFIG_FILE} | jq '.authIssuerClientId' | sed -e 's/"//g'`
CLOUDFRONT_URL=`cat ../${CONFIG_FILE} | jq '.cloudFrontUrl' | sed -e "s/https:\/\///g" | sed -e 's/"//g'`

mkdir -p ./tmp

cat ../templates/static/auth/google/index.html | \
    sed -e "s/%AUTH_ISSUER_CLIENT_ID%/${AUTH_ISSUER_CLIENT_ID}/g" | \
    sed -e "s/%LOGIN_CALLBACK_URL%/https:\/\/${CLOUDFRONT_URL}\/auth\/callback/g" > ./tmp/index.html

#
# upload to s3
# ----------------------------

aws s3 cp ./tmp/index.html s3://$STATIC_PAGE_BUCKET_NAME/auth/
aws s3 cp ../config/config.json s3://$CONFIG_BUCKET_NAME

#
# cleanup
# ----------------------------

rm ./tmp/index.html
