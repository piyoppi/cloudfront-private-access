#!/bin/sh

eval `cat ./.define.env`

BASEPATH=`dirname $0`
if [ ! -e $BASEPATH/$ENVFILE ]; then
    echo '[ERROR] config file (bin/.env) is not found.'
    exit 255
fi

if [ ! -e $1 ]; then
    echo '[ERROR] key file is not found.'
    exit 255
fi

aws s3 cp $1 s3://$CONFIG_BUCKET_NAME
