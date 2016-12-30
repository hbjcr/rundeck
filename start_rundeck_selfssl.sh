docker run -d \
    -p 443:4443 \
    -e SERVER_SECURED_URL=https://`hostname --ip-address` \
    --name rundeck -h rundeck \
    hbjcr/rundeck
