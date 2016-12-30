docker run -d \
    -p 4440:4440 \
    -e SERVER_URL=http://`hostname --ip-address`:4440 \
    -e DB_HOST=`hostname --ip-address` \
    -e DB_USER=rundeck \
    -e DB_PASSWORD=rundeck \
    --name rundeck -h rundeck \
    rundeck
