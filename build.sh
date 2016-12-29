#!/bin/bash
VERSION=2.7.1
NAME="automation/rundeck"

#docker build -t $NAME .
docker build -t $NAME:$VERSION .
docker tag -f  $NAME:$VERSION $NAME:latest
