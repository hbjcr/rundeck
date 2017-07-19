#!/bin/bash
VERSION=2.8.4
NAME="hbjcr/rundeck"

#docker build -t $NAME .
docker build -t $NAME:$VERSION .
docker tag $NAME:$VERSION $NAME:latest
