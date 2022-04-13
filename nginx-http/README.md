### Building the image

Build the image in the repository root

``` sh
docker build -t nginx-http nginx-http/
docker tag nginx-http registry.gitlab.com/kanaliiga/stream-rtmp/nginx-http
docker push registry.gitlab.com/kanaliiga/stream-rtmp/nginx-http
```

### Running the image

```sh
docker pull registry.gitlab.com/kanaliiga/stream-rtmp/nginx-http
docker network create -d bridge stream
docker run --rm --net stream --name nginx-http -p 80:80 -d --add-host=host.docker.internal:host-gateway registry.gitlab.com/kanaliiga/stream-rtmp/nginx-http
```
