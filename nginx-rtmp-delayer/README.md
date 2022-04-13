### Running the container

```sh
docker pull registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp
docker run --net stream --name nginx-rtmp-$CASTER -P -d -e CASTER=$CASTER -e CHANNEL=$CHANNEL -e FQDN=${FQDN} -e TWITCH_STREAM_KEY=$TWITCH_STREAM_KEY -e INTERNAL_STREAM_KEY=$INTERNAL_STREAM_KEY -e STREAM_DELAY=$STREAM_DELAY registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp
```
