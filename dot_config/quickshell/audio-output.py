import json
import subprocess
import sys

from audio_availability import available_outputs


def select_output(name):
    if name not in available_outputs():
        raise ValueError("This audio output is unavailable.")
    subprocess.run(['pactl', 'set-default-sink', name], check=True, capture_output=True, text=True)
    result = subprocess.run(['pactl', '--format=json', 'list', 'sink-inputs'], check=True, capture_output=True, text=True)
    for stream in json.loads(result.stdout):
        subprocess.run(['pactl', 'move-sink-input', str(stream['index']), name], check=True, capture_output=True, text=True)


if __name__ == '__main__':
    try:
        select_output(sys.argv[1])
    except (subprocess.CalledProcessError, ValueError, KeyError, IndexError, OSError) as error:
        print(getattr(error, 'stderr', '') or str(error), file=sys.stderr)
        sys.exit(1)
