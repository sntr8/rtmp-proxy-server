# RTMP Stream Delayer

A Python script that delays RTMP stream files before publishing them to a destination server.

## Purpose

This script watches a directory for `.flv` video files and publishes them to an RTMP destination after a configurable delay. This is useful for:
- Adding broadcast delay to live streams
- Preventing stream sniping in competitive gaming
- Time-shifting content

## How It Works

1. Monitors a work directory for `.flv` files
2. Extracts stream start timestamp from filename (e.g., `stream-1234567890.flv`)
3. Calculates when to publish: `timestamp + delay`
4. Waits for the configured delay period
5. Publishes the stream to RTMP using ffmpeg
6. Removes the file after successful publishing
7. Continuously waits for and processes new files

## File Naming Convention

The script expects files to be named with a Unix timestamp:
```
stream-1234567890.flv
```

Where `1234567890` is the Unix timestamp when recording started. This is the default format used by nginx-rtmp-module. The timestamp in the filename is used to calculate the delay, **not** the file modification time. This allows the script to work correctly even while the file is still being written to.

## Configuration

The script reads settings from `delayer_settings.py`:

- `DELAY` - Delay in seconds
- `STREAM_DESTINATION` - RTMP URL to publish to
- `FFMPEG_EXECUTABLE` - Path to ffmpeg
- `FFMPEG_EXTRA_OPTS` - Additional ffmpeg arguments (list)

## Usage

```bash
# Basic usage (uses settings from delayer_settings.py)
python3 stream_delayer.py /path/to/workdir

# Override settings with command line options
python3 stream_delayer.py -w 480 -d rtmp://server/app/key /path/to/workdir

# Verbose logging
python3 stream_delayer.py -v /path/to/workdir
```

## Command Line Options

- `stream_dir` - Directory containing .flv stream files (required)
- `-d, --destination URL` - Override RTMP destination URL
- `-w, --delay SECONDS` - Override delay in seconds
- `-v, --verbose` - Enable debug logging
- `-q, --quiet` - Reduce logging output

## Example

```bash
# Delay streams by 8 minutes (480 seconds)
python3 stream_delayer.py -w 480 -d rtmp://localhost/stream/key /opt/rtmp/workdir
```

## PID Locking

The script creates a PID file (`stream_delayer.pid`) in the work directory to prevent multiple instances from running simultaneously.

## Requirements

- Python 3.6+
- ffmpeg
- Write access to work directory

## License

Copyright 2026. All rights reserved.
