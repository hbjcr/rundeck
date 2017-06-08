#!/bin/bash
VERSION=2.8.2
NAME="hbjcr/rundeck"

#docker build -t $NAME .
docker build -t $NAME:$VERSION .
docker tag $NAME:$VERSION $NAME:latest
