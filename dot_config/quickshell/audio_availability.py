import json
import re
import subprocess
import sys
from pathlib import Path


def port_available(port):
    value = str(port.get('availability', port.get('available', 'unknown'))).lower()
    if value in ('yes', 'available', 'true'):
        return True
    if value in ('no', 'not available', 'unavailable', 'false'):
        return False
    return None


def hdmi_connected(properties):
    card = str(properties.get('alsa.card', ''))
    device = str(properties.get('alsa.device', ''))
    if not card.isdigit() or not device.isdigit():
        return False
    try:
        info = Path(f'/proc/asound/card{card}/pcm{device}p/info').read_text()
        match = re.search(r'(?:id|name):.*HDMI\s*(\d+)', info)
        if not match:
            return False
        files = Path(f'/proc/asound/card{card}').glob(f'eld#{match[1]}.*')
        return any(re.search(r'monitor_present\s+1', text) and re.search(r'eld_valid\s+1', text)
                   for text in (file.read_text() for file in files))
    except OSError:
        return False


def sink_available(sink):
    properties = sink.get('properties', {})
    details = ' '.join(str(value) for value in (sink.get('name', ''), sink.get('description', ''), properties.get('alsa.name', '')))
    digital = bool(re.search(r'hdmi|displayport', details, re.I))
    ports = sink.get('ports', [])
    if isinstance(ports, dict):
        ports = [dict(port, name=name) for name, port in ports.items()]
    active = sink.get('active_port')
    if isinstance(active, dict):
        active = active.get('name')
    selected = next((port for port in ports if port.get('name') == active), None)
    if selected:
        state = port_available(selected)
        if state is not None:
            return state
    elif ports:
        states = [port_available(port) for port in ports]
        if True in states:
            return True
        if all(state is False for state in states):
            return False
    return hdmi_connected(properties) if digital else True


def available_outputs():
    result = subprocess.run(['pactl', '--format=json', 'list', 'sinks'], check=True, capture_output=True, text=True)
    return [sink['name'] for sink in json.loads(result.stdout) if sink_available(sink)]


def available_inputs():
    result = subprocess.run(['pactl', '--format=json', 'list', 'sources'], check=True, capture_output=True, text=True)
    return [{'name': source['name'], 'description': source.get('description') or source['name']}
            for source in json.loads(result.stdout)
            if not source['name'].endswith('.monitor') and sink_available(source)]


if __name__ == '__main__':
    try:
        print(json.dumps(available_inputs() if '--inputs' in sys.argv else available_outputs()), flush=True)
    except (subprocess.CalledProcessError, ValueError, KeyError, OSError):
        print('[]', flush=True)
