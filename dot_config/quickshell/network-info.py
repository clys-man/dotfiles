import json
import subprocess


def parse_connections(text):
    devices = []
    current = None
    fields = {'IP4.ADDRESS': 'ipv4', 'IP4.GATEWAY': 'gateway', 'IP4.DNS': 'dns', 'IP6.ADDRESS': 'ipv6'}
    for line in text.splitlines():
        key, separator, value = line.partition(':')
        if not separator:
            continue
        key = key.split('[')[0]
        if key == 'GENERAL.DEVICE':
            current = {'interface': value, 'connected': False, 'ipv4': [], 'ipv6': [], 'gateway': [], 'dns': []}
            devices.append(current)
        elif current is not None:
            if key == 'GENERAL.STATE':
                current['connected'] = value.split(' ', 1)[0] == '100'
            elif key in fields and value and value != '--':
                current[fields[key]].append(value)
    return [device for device in devices if device['connected'] and (device['ipv4'] or device['ipv6'])]


if __name__ == '__main__':
    try:
        result = subprocess.run(['nmcli', '--terse', '--escape', 'no', '--fields', 'GENERAL.DEVICE,GENERAL.STATE,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS', 'device', 'show'], check=True, capture_output=True, text=True, timeout=3)
        print(json.dumps(parse_connections(result.stdout)), flush=True)
    except (OSError, subprocess.SubprocessError):
        print('[]', flush=True)
