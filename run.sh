#!/bin/bash

# OPTIONS:

# USER SETTINGS
#   DEFAULT_ADMIN_USER          Set the default admin user (defaults to "admin")
#   DEFAULT_ADMIN_PASSWORD      Set the default admin's password (defaults to "rundeck"). Must be at least 6 chars long
#   DEFAULT_USER                Set the default user (defaults to "guest")
#   DEFAULT_PASSWORD            Set the default user's password (defaults to "rundeck")

# SERVER SETTINGS
#   SERVER_MEMORY               Increases maximum permanent generation size
#   SERVER_URL                  Sets Rundeck's grails.serverURL
#   SERVER_PORT                 Sets Rundeck's listening port (defaults to "4440")
#   USE_INTERNAL_IP             When SERVER_URL is undefined, use the container's eth0 address (otherwise try to guess external)

# SSL SETTINGS
#   SERVER_SECURED_URL          Sets Rundeck's grails.serverURL and HTTPS protocol
#   SERVER_SECURED_PORT         Sets Rundeck's listening secured port (defaults to "4443")
#   PFX_CERTIFICATE_URL         URL location of the PFX certificate to be used in the SSL certificate; if not provided then a personal SSL will be generated
#   PFX_CERTIFICATE_PASSWORD    Password used to decrypt the private contents of your PFX file

# DB SETTINGS - jdbc:${JDBC_DRIVER:-postgresql}://${DB_HOST}:${DB_PORT:-5432}/${DB_NAME:-rundeck}?autoReconnect=true
#   JDBC_DRIVER                 Enables interaction with a db (defaults to "postgresql", another common option is "mysql")
#   DB_HOST                     Database server host address (if not provided then local storage used)
#   DB_PORT                     Database server listening port (defaults to "5432")
#   DB_NAME                     Rundeck's database name (defaults to "rundeck"; the database won't be created for you, you need to create upfront, prior to running your container)
#   DB_USER                     Database username (defaults to "rundeck")
#   DB_PASSWORD                 Database password (defaults to "rundeck")

# EMAIL SETTINGS
#	MAIL_HOST                   Email server host address (if not provided then no email notifications will be available)
#	MAIL_PORT                   Email server port number (defaults to "25")
#	MAIL_FROM                   From email account
#	MAIL_USER                   Email server username
#	MAIL_PASSWORD               Email server password

# ACTIVE DIRECTORY SETTINGS
#	AD_HOST                     Active Directory (AD) server to be used
#	AD_PORT                     AD server port number (defaults to "389")
#	AD_BINDN					Username used to query your AD in distinguised name (DN) form  e.g. "cn=myusername,dc=example,dc=com" (https://msdn.microsoft.com/en-us/library/windows/desktop/aa366101(v=vs.85).aspx)
#	AD_BINPASSWORD				Password used to query your AD in clear text
#	AD_USERBASEDN				Base DN to search for users, this is the OU which recursive searches for users will be performed on, e.g. "ou=People,dc=test1,dc=example,dc=com"
#	AD_ROLEBASEDN				Base DN for role membership search, this is where your "rundeck" AD user group is, e.g. "ou=Groups,dc=test1,dc=example,dc=com".

config_properties=$RDECK_BASE/server/config/rundeck-config.properties
realm_properties=$RDECK_BASE/server/config/realm.properties
ssl_properties=$RDECK_BASE/server/config/ssl.properties
framework_properties=$RDECK_BASE/etc/framework.properties
keystore_file=$RDECK_BASE/ssl/keystore
truststore_file=$RDECK_BASE/ssl/truststore
pfx_certificate_file=$RDECK_BASE/ssl/rundeck.pfx
initfile=/etc/rundeck.init

mem=${SERVER_MEMORY:-1024}
perm=$(($mem/4))

if [ ! -f "${initfile}" ]; then

	function install_rundeck() {
		echo "==> Installing rundeck"
		java -jar $RDECK_JAR --installonly
		echo "${DEFAULT_ADMIN_USER:-admin}:${DEFAULT_ADMIN_PASSWORD:-rundeck},user,admin" > $realm_properties
		echo "${DEFAULT_USER:-guest}:${DEFAULT_PASSWORD:-rundeck},user" >> $realm_properties
	}

	function config_grails_url() {
		echo "==> Generating serverURL"
		# Get eth0's IP
		if [ -z ${SERVER_URL} ]; then
			ext_ip=$(curl --silent http://ipv4bot.whatismyipaddress.com)
			int_ip=$(ip -4 -o addr show scope global eth0 | awk '{gsub(/\/.*/,"",$4); print $4}')
			if [ -z ${USE_INTERNAL_IP} ]; then
				SERVER_URL=http://${ext_ip}:${SERVER_PORT:-4440}
			else
				SERVER_URL=http://${int_ip}:${SERVER_PORT:-4440}
			fi
		fi
		sed -i "s,^grails\.serverURL.*\$,grails\.serverURL=${SERVER_URL}," $config_properties
	}

	function config_ssl() {
		echo "==> Configuring SSL"
		# Check if an external certificate was provided or if one internal will have to be generated
		if [ ! -f /root/.ssh/id_rsa ]; then
				echo "==> Self-generating SSH key"
				ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ''
				cat /root/.ssh/id_rsa.pub
		fi

		if [ -z ${PFX_CERTIFICATE_URL} ]; then
				# http://rundeck.org/docs/administration/configuring-ssl.html
				echo "==> Creating a Java keystore & truststore to hold a new rundeck self-signed certificate"
				keytool -genkey \
						-alias rundeck \
						-keystore $keystore_file \
						-keyalg RSA \
						-keypass ${DEFAULT_ADMIN_PASSWORD:-rundeck} \
						-storepass ${DEFAULT_ADMIN_PASSWORD:-rundeck} \
						-dname "CN=localhost, O=myorg, C=US"
		else
				# https://runops.wordpress.com/2015/11/22/setup-rundeck-with-ssl/
				echo "==> Installing PFX certificate"
				echo "Downloading: ${PFX_CERTIFICATE_URL}"
				#wget -Y off -O $pfx_certificate_file ${PFX_CERTIFICATE_URL}
				curl -L -k -o $pfx_certificate_file ${PFX_CERTIFICATE_URL}

				# Retrieve the alias from the PKCS #12 file
				key_alias=$(keytool -list -storetype pkcs12 -keystore $pfx_certificate_file -storepass ${PFX_CERTIFICATE_PASSWORD} | tail -2 | head -1 | sed -e 's/,/\n/g' | head -1)
				echo $key_alias

				# Import the Certificate and Private Key into the Java keystore
				keytool -importkeystore -deststorepass ${DEFAULT_ADMIN_PASSWORD:-rundeck} -destkeypass ${DEFAULT_ADMIN_PASSWORD:-rundeck} -destkeystore $keystore_file -srckeystore $pfx_certificate_file -srcstoretype PKCS12 -srcstorepass ${PFX_CERTIFICATE_PASSWORD} -srcalias $key_alias -alias $key_alias

				keytool -list -keystore $keystore_file
		fi

		cp $keystore_file $truststore_file

		echo "==> Generating ssl.properties configuration file"

		echo "keystore=$keystore_file" > $ssl_properties
		echo "keystore.password=${DEFAULT_ADMIN_PASSWORD:-rundeck}" >> $ssl_properties
		echo "key.password=${DEFAULT_ADMIN_PASSWORD:-rundeck}" >> $ssl_properties
		echo "truststore=$truststore_file" >> $ssl_properties
		echo "truststore.password=${DEFAULT_ADMIN_PASSWORD:-rundeck}" >> $ssl_properties

		echo "==> Configuring rundeck-config.properties file"

		sed -i "s,^grails\.serverURL.*\$,grails\.serverURL=${SERVER_SECURED_URL}," $config_properties
	}

	function config_database() {
		sql_datasource="dataSource.url = jdbc:${JDBC_DRIVER:-postgresql}://${DB_HOST}:${DB_PORT:-5432}/${DB_NAME:-rundeck}?autoReconnect=true"
		sql_un="dataSource.username = ${DB_USER:-rundeck}"
		sql_pw="dataSource.password = ${DB_PASSWORD:-rundeck}"
		storage_settings="rundeck.projectsStorageType=db\nrundeck.storage.provider.1.type=db\nrundeck.storage.provider.1.path=keys"
		sed -i "s,^dataSource\.url.*\$,${sql_datasource}," $config_properties
		echo $sql_un >> $config_properties; echo $sql_pw >> $config_properties
		echo -e $storage_settings >> $config_properties
	}

	function config_mail() {
		echo "grails.mail.host=${MAIL_HOST}" >> $config_properties
		echo "grails.mail.port=${MAIL_PORT:-25}" >> $config_properties
		echo "grails.mail.default.from=${MAIL_FROM}" >> $config_properties
		echo "grails.mail.username=${MAIL_USER}" >> $config_properties
		echo "grails.mail.password=${MAIL_PASSWORD}" >> $config_properties
	}

	install_rundeck

	# Use regular http only when https won't be used
	if [ -z ${SERVER_SECURED_URL} ]; then
		echo "=> HTTP Configuration"
		config_grails_url
	fi

	if ! [ -z ${SERVER_SECURED_URL} ]; then
		echo "=> HTTPS Configuration"
		config_ssl
	fi

	# If DB is not used then local storage will be used instead
	if ! [ -z ${DB_HOST} ]; then
		echo "=> DB Configuration"
		config_database
	fi

	if ! [ -z ${MAIL_HOST} ]; then
		echo "=> Mail Configuration"
		config_mail
	fi
	
	touch ${initfile}
fi

params="-Xmx${mem}m "
params="$params -XX:MaxPermSize=${perm}m "
params="$params -Drundeck.jetty.connector.forwarded=true "

if [ -z ${SERVER_SECURED_URL} ]; then
	params="$params -Dserver.http.host=0.0.0.0 "
	params="$params -Dserver.hostname=$(hostname) "
	params="$params -Dserver.http.port=${SERVER_PORT:-4440} "
else
	params="$params -Drundeck.ssl.config=$ssl_properties "
	params="$params -Dserver.https.port=${SERVER_SECURED_PORT:-4443}"
	params="$params -Djavax.net.ssl.trustStore=$truststore_file"
	params="$params -Djavax.net.ssl.trustStoreType=jks"
	params="$params -Djava.protocol.handler.pkgs=com.sun.net.ssl.internal.www.protocol"
fi

if ! [ -z ${AD_HOST} ]; then
	# References:
	# http://rundeck.org/docs/administration/authenticating-users.html
	# https://meinit.nl/connect-rundeck-active-directory
	# https://runops.wordpress.com/2015/11/20/configure-rundeck-to-use-active-directory-authentication/
	# http://www.techpaste.com/2015/06/rundeck-active-directory-integration-steps/
	sed -i "s/<AD_HOST>/${AD_HOST}/" $RDECK_BASE/server/config/jaas-activedirectory.conf
	sed -i "s/<AD_PORT>/${AD_PORT:-389}/" $RDECK_BASE/server/config/jaas-activedirectory.conf
	
	sed -i "s/<AD_BINDN>/${AD_BINDN}/" $RDECK_BASE/server/config/jaas-activedirectory.conf
	sed -i "s/<AD_BINPASSWORD>/${AD_BINPASSWORD}/" $RDECK_BASE/server/config/jaas-activedirectory.conf
	sed -i "s/<AD_USERBASEDN>/${AD_USERBASEDN}/" $RDECK_BASE/server/config/jaas-activedirectory.conf
	sed -i "s/<AD_ROLEBASEDN>/${AD_ROLEBASEDN}/" $RDECK_BASE/server/config/jaas-activedirectory.conf
	
	params="$params -Dloginmodule.conf.name=jaas-activedirectory.conf "
	params="$params -Dloginmodule.name=activedirectory "
fi

params="$params -jar $RDECK_JAR --skipinstall"

# Setup completed, ready to start the server
echo "STARTING RUNDECK >>>"
echo $params
exec java $params &

rd_pid=$!
wait $rd_pid
echo "RUNDECK EXECUTION STOPPED UNEXPECTEDLY"
