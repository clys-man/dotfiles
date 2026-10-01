import html
import os
from pathlib import Path
import pwd
import sys


def read(path):
    try:
        return path.read_text().strip()
    except OSError:
        return ""


def battery(root=Path("/sys/class/power_supply")):
    values = []
    for device in sorted(root.glob("*")):
        if read(device / "type") != "Battery":
            continue
        if read(device / "scope") == "Device" or read(device / "present") == "0":
            continue
        capacity = read(device / "capacity")
        if not capacity.isdigit():
            continue
        status = read(device / "status")
        plugged = status == "Charging" or any(
            read(supply / "type") in {"Mains", "USB", "USB_C", "USB_PD"}
            and read(supply / "online") == "1"
            for supply in root.glob("*")
        )
        label = "Fully charged" if status == "Full" else "Charging" if status == "Charging" else "Plugged in" if plugged else "Battery"
        values.append(f"{label} · {capacity}%")
    return "   ·   ".join(values)


def caps(root=Path("/sys/class/leds")):
    return "Caps Lock is on" if any(read(led / "brightness") == "1" for led in root.glob("*::capslock")) else ""


def avatar():
    home = Path.home()
    user = pwd.getpwuid(os.getuid()).pw_name
    for path in [home / ".profile.png", home / ".face", home / ".face.icon", Path("/var/lib/AccountsService/icons") / user]:
        if path.is_file() and os.access(path, os.R_OK):
            return str(path)
    return str(home / ".config/hypr/lock-avatar.png")


def username():
    user = pwd.getpwuid(os.getuid())
    return html.escape(user.pw_gecos.split(",")[0] or user.pw_name)


if __name__ == "__main__":
    commands = {"battery": battery, "caps": caps, "avatar": avatar, "user": username}
    action = commands.get(sys.argv[1] if len(sys.argv) > 1 else "")
    if action is None:
        raise SystemExit(2)
    print(action())
