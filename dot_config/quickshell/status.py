import json
import pathlib
import re
import shutil
import subprocess
import time

from audio_device import output_icon


def command(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=2).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def read(path):
    try:
        return pathlib.Path(path).read_text().strip()
    except OSError:
        return ""


previous = None
while True:
    ticks = list(map(int, read('/proc/stat').splitlines()[0].split()[1:9]))
    total, idle = sum(ticks), ticks[3] + ticks[4]
    cpu = 0 if previous is None or total == previous[0] else round(100 * (1 - (idle - previous[1]) / (total - previous[0])))
    previous = total, idle
    mem = dict(re.findall(r'(\w+):\s+(\d+)', read('/proc/meminfo')))
    memory = round(100 * (1 - int(mem['MemAvailable']) / int(mem['MemTotal'])))
    storage = None
    try:
        disk = shutil.disk_usage("/")
        storage = round(100 * disk.used / disk.total) if disk.total else None
    except OSError:
        pass
    brightness = None
    for device in pathlib.Path('/sys/class/backlight').glob('*'):
        maximum = read(device / 'max_brightness')
        if maximum and int(maximum):
            brightness = round(100 * int(read(device / 'brightness')) / int(maximum))
            break
    battery = None
    for device in pathlib.Path('/sys/class/power_supply').glob('*'):
        if read(device / 'type') == 'Battery':
            battery = {'percent': read(device / 'capacity'), 'charging': read(device / 'status') in ('Charging', 'Full')}
            break
    audio = {}
    for key, target in [('volume', '@DEFAULT_AUDIO_SINK@'), ('mic', '@DEFAULT_AUDIO_SOURCE@')]:
        value = command('wpctl', 'get-volume', target)
        match = re.search(r'Volume: ([\d.]+)', value)
        audio[key] = {'percent': round(float(match[1]) * 100) if match else 0, 'muted': 'MUTED' in value}
    audio_devices = {}
    try:
        sinks = json.loads(command('pactl', '--format=json', 'list', 'sinks'))
        audio_devices = {sink['name']: output_icon(sink) for sink in sinks}
    except (ValueError, KeyError, TypeError):
        pass
    connections = command('nmcli', '-t', '-f', 'TYPE,NAME', 'connection', 'show', '--active').splitlines()
    network = next((line.partition(':')[2] for line in connections if line.startswith(('802-11-wireless:', '802-3-ethernet:'))), '')
    print(json.dumps({'cpu': cpu, 'memory': memory, 'storage': storage, 'audioDevices': audio_devices, 'brightness': brightness, 'battery': battery, 'network': network, 'night': bool(command('pgrep', '-x', 'gammastep')), **audio}), flush=True)
    time.sleep(2)
