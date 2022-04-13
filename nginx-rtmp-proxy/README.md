### Running the container

```sh
docker pull registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp-nodelay
docker run --net stream --name nginx-rtmp-$CASTER -P -d -e CASTER=$CASTER -e CHANNEL=$CHANNEL -e TWITCH_STREAM_KEY=$TWITCH_STREAM_KEY registry.gitlab.com/kanaliiga/stream-rtmp/nginx-rtmp-nodelay
```
