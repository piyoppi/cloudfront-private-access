#!/bin/sh

BASEPATH=`dirname $0`

eval `cat $BASEPATH/.define.env`

if [ ! -e $BASEPATH/../$ENVFILE ]; then
    echo '[ERROR] config file (bin/.env) is not found.'
    exit 255
fi

if [ ! -e $1 ]; then
    echo '[ERROR] key file is not found.'
    exit 255
fi

eval `cat $BASEPATH/../$ENVFILE`

aws s3 cp $1 s3://$CONFIG_BUCKET_NAME
