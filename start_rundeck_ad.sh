#!/bin/bash
docker run -d \
	-v /etc/localtime:/etc/localtime:ro \
	-v /etc/timezone:/etc/timezone:ro \
	-p 80:4440 \
	-p 443:4443 \
	-e DB_HOST=dbconnection.example.com \
	-e DB_USER=postgres \
	-e DB_PASSWORD=postgres \
	-e SERVER_SECURED_URL=https://rundeck.example.com \
	-e PFX_CERTIFICATE_URL=rundeck.example.com.pfx \
	-e PFX_CERTIFICATE_PASSWORD=example \
	-e MAIL_HOST=smtp.example.com \
	-e MAIL_FROM=from@example.com \
	-e MAIL_USER=to@example.com \
	-e MAIL_PASSWORD=mypassword  \
	-e AD_HOST=corpad.example.com \
	-e AD_PORT=389 \
	-e AD_BINDN=CN="exampleaccount,OU=ExampleOU,DC=example,DC=com" \
	-e AD_BINPASSWORD="mypassword " \
	-e AD_USERBASEDN="DC=example,DC=com" \
	-e AD_ROLEBASEDN="CN=example_developer,OU=ExampleOU,DC=example,DC=com" \
	--name rundeck -h rundeck \
	hbjcr/rundeck
