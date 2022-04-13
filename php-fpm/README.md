### Building the image

Build the image in the repository root

```sh
docker build -t php-fpm -f php-fpm/Dockerfile .
docker tag php-fpm registry.gitlab.com/kanaliiga/stream-rtmp/php-fpm
docker push registry.gitlab.com/kanaliiga/stream-rtmp/php-fpm
```

### Running the image

**NOTE:** Ensure stream network has been created. Check the info for network from nginx-http README.md.

```sh
docker pull registry.gitlab.com/kanaliiga/stream-rtmp/php-fpm
docker run --rm --net stream --name php-fpm -e MYSQL_USER=${MYSQL_USER} -e MYSQL_PASSWORD=${MYSQL_PASSWORD} -e MYSQL_DATABASE=${MYSQL_DATABASE} -d registry.gitlab.com/kanaliiga/stream-rtmp/php-fpm
```
