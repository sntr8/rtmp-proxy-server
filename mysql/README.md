### Running the container

```sh
sudo docker run --rm --name mysql --net stream -v /opt/mysql/data/:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} -e MYSQL_USER=${MYSQL_USER} -e MYSQL_PASSWORD=${MYSQL_PASSWORD} -e MYSQL_DATABASE=${MYSQL_DATABASE} -d registry.gitlab.com/kanaliiga/stream-rtmp/mysql
docker exec -it mysql /bin/bash -c 'envsubst < /creds.cnf.template > /creds.cnf'
```
