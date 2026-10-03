import json
import subprocess
import sys

from audio_availability import available_inputs


def select_input(name):
    if name not in [source['name'] for source in available_inputs()]:
        raise ValueError('This audio input is unavailable.')
    subprocess.run(['pactl', 'set-default-source', name], check=True, capture_output=True, text=True)
    result = subprocess.run(['pactl', '--format=json', 'list', 'source-outputs'], check=True, capture_output=True, text=True)
    for stream in json.loads(result.stdout):
        subprocess.run(['pactl', 'move-source-output', str(stream['index']), name], check=True, capture_output=True, text=True)


if __name__ == '__main__':
    try:
        select_input(sys.argv[1])
    except (subprocess.CalledProcessError, ValueError, KeyError, IndexError, OSError) as error:
        print(getattr(error, 'stderr', '') or str(error), file=sys.stderr)
        sys.exit(1)
