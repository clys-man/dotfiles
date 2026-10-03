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
usb_devices = []
usb_device_names = {}
next_usb_update = 0
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
        if read(device / 'type') != 'Battery' or read(device / 'scope') == 'Device':
            continue
        capacity = read(device / 'capacity')
        if read(device / 'present') == '0' or not capacity.isdigit() or not 0 <= int(capacity) <= 100:
            continue
        battery = {'percent': capacity, 'charging': read(device / 'status') in ('Charging', 'Full')}
        break
    if time.monotonic() >= next_usb_update:
        usb_devices = []
        connected_ids = command('idevice_id', '-l').splitlines()
        usb_device_names = {uid: name for uid, name in usb_device_names.items() if uid in connected_ids}
        for uid in connected_ids:
            capacity = command('ideviceinfo', '-u', uid, '-q', 'com.apple.mobile.battery', '-k', 'BatteryCurrentCapacity')
            if not capacity.isdigit() or not 0 <= int(capacity) <= 100:
                continue
            if uid not in usb_device_names:
                usb_device_names[uid] = command('ideviceinfo', '-u', uid, '-k', 'DeviceName') or 'iPhone'
            usb_devices.append({'name': usb_device_names[uid], 'icon': 'phone', 'battery': int(capacity) / 100})
        mtp_info = command('mtp-detect')
        for device_info in mtp_info.split('Device info:')[1:]:
            model = re.search(r'^\s*Model:\s*(.+)$', device_info, re.MULTILINE)
            battery_level = re.search(r'Battery level (\d+) of (\d+)', device_info)
            if not battery_level or int(battery_level[2]) <= 0:
                continue
            fraction = int(battery_level[1]) / int(battery_level[2])
            if not 0 <= fraction <= 1:
                continue
            name = model[1].strip() if model else 'Android'
            usb_devices.append({'name': name, 'icon': 'phone', 'battery': fraction})
        next_usb_update = time.monotonic() + 5
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
    vpn = [line.partition(':')[2] for line in connections if line.startswith(('vpn:', 'wireguard:'))]
    keyboard = None
    try:
        keyboards = json.loads(command('hyprctl', 'devices', '-j')).get('keyboards', [])
        device = next((device for device in keyboards if device.get('main')), keyboards[0] if keyboards else None)
        if device:
            layouts = device.get('layout', '').split(',')
            index = device.get('active_layout_index', 0)
            keyboard = {'layout': layouts[index].upper() if 0 <= index < len(layouts) else device.get('active_keymap', ''),
                        'name': device.get('active_keymap', '')}
    except (ValueError, TypeError, KeyError):
        pass
    print(json.dumps({'cpu': cpu, 'memory': memory, 'storage': storage, 'audioDevices': audio_devices, 'brightness': brightness, 'battery': battery, 'usbDevices': usb_devices, 'network': network, 'vpn': vpn, 'keyboard': keyboard, 'night': bool(command('pgrep', '-x', 'gammastep')), **audio}), flush=True)
    time.sleep(2)
