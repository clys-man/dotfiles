import re


def output_icon(sink):
    properties = sink.get('properties', {})
    name = sink.get('name', '')
    if name.startswith('bluez_output.') or properties.get('device.api') == 'bluez5' or properties.get('api.bluez5.address'):
        return 'bluetooth'
    port = sink.get('active_port', '')
    if isinstance(port, dict):
        port = port.get('name', '')
    details = ' '.join(str(value) for value in (port, properties.get('device.form_factor', ''), properties.get('device.profile.description', ''), sink.get('description', '')))
    return 'headphones' if re.search(r'headphone|headset|earphone|fone', details, re.I) else 'volume'
