import json
import subprocess


def connections(active=False):
    args = ['nmcli', '--terse', '--escape', 'no', '--fields', 'UUID,TYPE,NAME', 'connection', 'show']
    if active:
        args.append('--active')
    result = subprocess.run(args, check=True, capture_output=True, text=True, timeout=5)
    return [line.split(':', 2) for line in result.stdout.splitlines() if line.count(':') >= 2]


def network_details(uuid):
    fields = {'GENERAL.DEVICES': 'interface', 'IP4.ADDRESS': 'ipv4', 'IP6.ADDRESS': 'ipv6',
              'IP4.GATEWAY': 'gateway', 'IP6.GATEWAY': 'gateway', 'IP4.DNS': 'dns', 'IP6.DNS': 'dns'}
    details = {key: [] for key in fields.values()}
    try:
        result = subprocess.run(['nmcli', '--terse', '--escape', 'no', '--fields', ','.join(fields),
                                 'connection', 'show', 'uuid', uuid],
                                check=True, capture_output=True, text=True, timeout=5)
        for line in result.stdout.splitlines():
            key, separator, value = line.partition(':')
            field = fields.get(key.split('[')[0])
            if separator and field and value and value != '--' and value not in details[field]:
                details[field].append(value)
        details['error'] = ''
    except (OSError, subprocess.SubprocessError):
        details['error'] = 'Could not read VPN network details.'
    return details


def vpn_connections():
    active = {uuid for uuid, kind, name in connections(True)}
    return [{'uuid': uuid, 'name': name, 'active': uuid in active}
            | {'details': network_details(uuid) if uuid in active else None}
            for uuid, kind, name in connections() if kind in ('vpn', 'wireguard')]


if __name__ == '__main__':
    try:
        print(json.dumps({'connections': vpn_connections(), 'error': ''}), flush=True)
    except (OSError, subprocess.SubprocessError) as error:
        print(json.dumps({'connections': [], 'error': 'Could not check VPN connections.'}), flush=True)
