#!/bin/bash
docker run -d \
	-v /etc/localtime:/etc/localtime:ro \
	-v /etc/timezone:/etc/timezone:ro \
	-e POSTGRES_USER=rundeck \
	-e POSTGRES_PASSWORD=rundeck \
	--name rundeck_db -h rundeck_db \
	postgres
