# End user manual

## Setting up OBS

OBS > Settings > Stream
Service: Custom...
Server: rtmp://stream.kanaliiga.fi/delay-<nick>/
Stream Key: <nick>-<hex>
- Do not use delay in OBS
- 8 minute delay on our stream server

## Using VLC

CO-CASTER / VLC
If you or a co-caster would like to see a live stream without delay, you can watch it with VLC like this:
VLC > CTRL+N
URL: rtmp://stream.kanaliiga.fi/delay-<nick>/<Caster Stream Key>
[x] Show more options
Caching: 500ms
Play
- Delay should be less than a second in VLC
- Probably want to mute sounds
