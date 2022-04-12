#!/bin/sh

cd `dirname $0`

eval `cat ./.define.env`

while getopts b: OPT
do
  case $OPT in
    "b" ) BUCKET_NAME_PREFIX="$OPTARG" ;;
  esac
done

STATIC_PAGE_BUCKET_NAME=${BUCKET_NAME_PREFIX}-staticpage
CONFIG_BUCKET_NAME=${BUCKET_NAME_PREFIX}-config

#
# create files from template
# ----------------------------

mkdir -p ../config
mkdir -p ../config/.generated
mkdir -p ../functions/.generated

cat ../templates/functions/.generated/configModule.js | sed -e "s/%BUCKET_NAME%/${CONFIG_BUCKET_NAME}/g" > ../functions/.generated/configModule.js
cat ../templates/template.yml | \
    sed -e "s/%STATIC_PAGE_BUCKET_NAME%/${STATIC_PAGE_BUCKET_NAME}/g" | \
    sed -e "s/%CONFIG_BUCKET_NAME%/${CONFIG_BUCKET_NAME}/g" > ../template.yml

if [ ! -e ../$CONFIG_FILE ]; then
    cp ../templates/$CONFIG_FILE ../$CONFIG_FILE
fi

#
# write config file
# ----------------------------

echo "STATIC_PAGE_BUCKET_NAME=${BUCKET_NAME_PREFIX}-staticpage" > ../$ENVFILE
echo "CONFIG_BUCKET_NAME=${BUCKET_NAME_PREFIX}-config" >> ../$ENVFILE
