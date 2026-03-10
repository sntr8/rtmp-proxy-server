#!/usr/bin/env python3
"""
RTMP Stream Delayer
Delays RTMP stream files by a configurable amount before publishing them.
"""

import argparse
import logging
import os
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Optional, List, Dict


class DelayedStreamPublisher:
    """Publishes RTMP stream files with a time delay by piping to FFmpeg."""

    def __init__(self, work_dir: str, rtmp_url: str, delay_seconds: int,
                 ffmpeg_path: str = "ffmpeg", ffmpeg_args: Optional[List[str]] = None):
        self.work_dir = Path(work_dir)
        self.rtmp_url = rtmp_url
        self.delay_seconds = delay_seconds
        self.ffmpeg_path = ffmpeg_path
        self.ffmpeg_args = ffmpeg_args or []
        self.logger = logging.getLogger(self.__class__.__name__)
        self.running = True

    def get_timestamp_from_filename(self, file_path: Path) -> int:
        """Extract Unix timestamp from filename (e.g. stream-1234567890.flv)."""
        try:
            return int(file_path.stem.split('-')[-1])
        except (ValueError, IndexError):
            self.logger.warning(f"Could not parse timestamp from filename: {file_path.name}")
            return 0

    def find_stream_files(self) -> List[Path]:
        """Find all .flv files sorted by embedded timestamp."""
        try:
            files = list(self.work_dir.glob("*.flv"))
            return sorted(files, key=self.get_timestamp_from_filename)
        except OSError as e:
            self.logger.error(f"Error scanning directory: {e}")
            return []

    def wait_for_stream(self) -> Optional[Path]:
        """Wait for a stream file to appear."""
        self.logger.info(f"Waiting for stream files in {self.work_dir}")
        while self.running:
            files = self.find_stream_files()
            if files:
                self.logger.info(f"Found {len(files)} stream file(s)")
                return files[0]
            time.sleep(0.5)
        return None

    def calculate_delay_time(self, file_path: Path) -> float:
        """Calculate wait time based on timestamp in filename."""
        stream_start_time = self.get_timestamp_from_filename(file_path)
        if stream_start_time == 0:
            return 0
        target_time = stream_start_time + self.delay_seconds
        return max(0, target_time - time.time())

    def is_file_growing(self, file_path: Path, check_duration: float = 2.0) -> bool:
        """Check if a file is actively being written to."""
        try:
            initial_size = file_path.stat().st_size
            time.sleep(check_duration)
            final_size = file_path.stat().st_size
            return final_size > initial_size
        except OSError:
            return False

    def _feed_stdin_thread(self, file_path: Path, process: subprocess.Popen, state: Dict):
        """Background thread to read the file and feed FFmpeg's stdin."""
        try:
            with open(file_path, 'rb') as f:
                while self.running and state['active']:
                    chunk = f.read(65536)
                    
                    if not chunk:
                        # Reached EOF, check if encoder is still writing
                        if self.is_file_growing(file_path, check_duration=0.5):
                            continue
                        else:
                            self.logger.info(f"Stream {file_path.name} is complete. Closing pipe.")
                            state['success'] = True
                            break
                    
                    # Feed FFmpeg
                    try:
                        process.stdin.write(chunk)
                        process.stdin.flush()
                        state['last_write_time'] = time.time()
                    except (BrokenPipeError, OSError):
                        # FFmpeg crashed or was killed by watchdog
                        break
        except Exception as e:
            self.logger.error(f"Error reading stream file: {e}")
        finally:
            # Signal EOF to FFmpeg
            if process.stdin:
                try:
                    process.stdin.close()
                except OSError:
                    pass
            state['active'] = False

    def _drain_stderr_thread(self, process: subprocess.Popen):
        """Background thread to read FFmpeg's stderr to prevent pipe deadlocks."""
        last_progress_log = time.time()
        
        # iter() with readline gracefully blocks until a newline is sent or EOF occurs
        for line_bytes in iter(process.stderr.readline, b''):
            line = line_bytes.decode('utf-8', errors='ignore').strip()
            if not line:
                continue
                
            # Log periodic progress
            if 'time=' in line.lower() and (time.time() - last_progress_log) > 10:
                self.logger.debug(f"FFmpeg progress: {line}")
                last_progress_log = time.time()
            elif "error" in line.lower() or "fail" in line.lower():
                self.logger.warning(f"FFmpeg: {line}")

    def publish_file(self, file_path: Path) -> bool:
        """
        Publish stream using background threads to ensure the main thread never freezes.
        """
        self.logger.info(f"Publishing {file_path.name} to {self.rtmp_url}")

        cmd = [
            self.ffmpeg_path,
            *self.ffmpeg_args,
            "-re",
            "-i", "pipe:0",
            "-c", "copy",
            "-f", "flv",
            self.rtmp_url
        ]

        process = None
        stall_timeout = 60.0
        
        # Shared state dictionary so threads can communicate with the main watchdog loop
        state = {
            'active': True,
            'success': False,
            'last_write_time': time.time()
        }

        try:
            process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE
            )

            # 1. Start Reader Thread (prevents stderr deadlock)
            stderr_thread = threading.Thread(target=self._drain_stderr_thread, args=(process,))
            stderr_thread.daemon = True
            stderr_thread.start()

            # 2. Start Writer Thread (prevents stdin deadlock)
            stdin_thread = threading.Thread(target=self._feed_stdin_thread, args=(file_path, process, state))
            stdin_thread.daemon = True
            stdin_thread.start()

            # 3. Main Thread (Watchdog Loop)
            while self.running and state['active']:
                # If FFmpeg died prematurely
                if process.poll() is not None:
                    if process.returncode != 0:
                        self.logger.error(f"FFmpeg exited unexpectedly with code {process.returncode}")
                    break
                
                # If the network stalled and the Writer Thread is permanently blocked
                if (time.time() - state['last_write_time']) > stall_timeout:
                    self.logger.error(f"Stream STALLED (no data accepted for {stall_timeout}s). Killing FFmpeg.")
                    break
                    
                time.sleep(1)

        except Exception as e:
            self.logger.error(f"Unexpected error managing FFmpeg: {e}")
        finally:
            state['active'] = False
            
            if process:
                if process.poll() is None:
                    self.logger.info("Terminating FFmpeg process...")
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                
                if process.stderr:
                    process.stderr.close()

        return state['success']

    def process_stream(self, file_path: Path) -> bool:
        """Wait for delay period, publish, and cleanup."""
        wait_time = self.calculate_delay_time(file_path)

        if wait_time > 0:
            self.logger.info(f"Delaying {file_path.name} for {wait_time:.1f} seconds")
            end_time = time.time() + wait_time
            while self.running and time.time() < end_time:
                time.sleep(0.5)

            if not self.running:
                return False

        success = self.publish_file(file_path)

        if success and not self.is_file_growing(file_path, check_duration=1.0):
            try:
                file_path.unlink()
                self.logger.info(f"Cleaned up completed file: {file_path.name}")
            except OSError as e:
                self.logger.warning(f"Could not remove {file_path.name}: {e}")
            return True
            
        return False

    def run(self):
        """Main processing loop."""
        self.logger.info("Stream delayer started")
        while self.running:
            stream_file = self.wait_for_stream()
            if not stream_file:
                break
            
            self.process_stream(stream_file)
            time.sleep(1)

        self.logger.info("Stream delayer stopped")

    def stop(self):
        """Signal the publisher to stop."""
        self.running = False


class PIDLock:
    """Simple PID file lock to prevent multiple instances."""
    def __init__(self, pid_file: Path):
        self.pid_file = pid_file

    def __enter__(self):
        if self.pid_file.exists():
            try:
                pid = int(self.pid_file.read_text().strip())
                os.kill(pid, 0)
                raise RuntimeError(f"Another instance is running (PID {pid})")
            except (OSError, ValueError):
                pass

        self.pid_file.write_text(str(os.getpid()))
        return self

    def __exit__(self, *args):
        try:
            self.pid_file.unlink()
        except OSError:
            pass


def setup_logging(verbose: bool = False, quiet: bool = False):
    """Configure logging output."""
    level = logging.INFO
    if verbose:
        level = logging.DEBUG
    elif quiet:
        level = logging.WARNING
    logging.basicConfig(level=level, format='%(asctime)s - %(levelname)s - %(message)s')


def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description='Delay RTMP stream files before publishing')
    parser.add_argument('stream_dir', help='Directory containing .flv stream files')
    parser.add_argument('-d', '--destination', help='RTMP destination URL')
    parser.add_argument('-w', '--delay', type=int, help='Delay in seconds')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose logging')
    parser.add_argument('-q', '--quiet', action='store_true', help='Reduce logging output')
    return parser.parse_args()


def main():
    """Main entry point."""
    args = parse_arguments()
    setup_logging(args.verbose, args.quiet)
    logger = logging.getLogger(__name__)

    # Default fallback settings
    STREAM_DESTINATION = "rtmp://localhost/live/delayed"
    DELAY = 60
    FFMPEG_EXECUTABLE = "ffmpeg"
    FFMPEG_EXTRA_OPTS = []

    # Attempt to load configuration, gracefully fallback if missing
    try:
        import delayer_settings as settings
        STREAM_DESTINATION = getattr(settings, 'STREAM_DESTINATION', STREAM_DESTINATION)
        DELAY = getattr(settings, 'DELAY', DELAY)
        FFMPEG_EXECUTABLE = getattr(settings, 'FFMPEG_EXECUTABLE', FFMPEG_EXECUTABLE)
        FFMPEG_EXTRA_OPTS = getattr(settings, 'FFMPEG_EXTRA_OPTS', FFMPEG_EXTRA_OPTS)
    except ImportError:
        logger.debug("delayer_settings.py not found. Relying on defaults and CLI arguments.")

    # Command line args override config
    destination = args.destination or STREAM_DESTINATION
    delay = args.delay if args.delay is not None else DELAY

    work_dir = Path(args.stream_dir)
    if not work_dir.is_dir():
        logger.error(f"Directory not found: {work_dir}")
        sys.exit(1)

    pid_file = work_dir / "stream_delayer.pid"

    try:
        with PIDLock(pid_file):
            publisher = DelayedStreamPublisher(
                work_dir=str(work_dir),
                rtmp_url=destination,
                delay_seconds=delay,
                ffmpeg_path=FFMPEG_EXECUTABLE,
                ffmpeg_args=FFMPEG_EXTRA_OPTS
            )

            def signal_handler(signum, frame):
                logger.info("Received shutdown signal")
                publisher.stop()

            signal.signal(signal.SIGTERM, signal_handler)
            signal.signal(signal.SIGINT, signal_handler)

            publisher.run()

    except RuntimeError as e:
        logger.error(str(e))
        sys.exit(1)
    except KeyboardInterrupt:
        logger.info("Interrupted by user")
    except Exception as e:
        logger.exception("Unexpected error")
        sys.exit(1)

if __name__ == '__main__':
    main()