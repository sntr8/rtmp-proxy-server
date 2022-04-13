DELAY = ${STREAM_DELAY}
STREAM_DESTINATION = 'rtmp://localhost/$CASTER-publish/$INTERNAL_STREAM_KEY'
SINGLE = True # Set to true to just delay a single stream and exit, no reconnecting/backup-streams
BACKUPSTREAM_SHORT = '' # Show while intermission
BACKUPSTREAM_LONG = '' # Show while longer downtime
FFMPEG_EXECUTABLE = "ffmpeg" # Use avconv if you need
FFMPEG_EXTRA_OPTS = [] # Add extra options if necessary
