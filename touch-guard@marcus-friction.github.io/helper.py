#!/usr/bin/python3
"""Hold exclusive grabs on touchscreen evdev nodes until stdin closes.

This program is installed root-owned and launched through pkexec. It accepts no
device paths or commands from its caller; udev supplies the device list.
"""

import fcntl
import glob
import os
import selectors
import subprocess
import sys


EVIOCGRAB = 0x40044590
SCAN_INTERVAL = 3
UDEVADM = "/usr/bin/udevadm"


def report(message):
    print(message, flush=True)


def touchscreen_nodes():
    nodes = {}
    for path in sorted(glob.glob("/dev/input/event[0-9]*")):
        result = subprocess.run(
            [UDEVADM, "info", "--query=property", "--name", path],
            capture_output=True,
            text=True,
            timeout=3,
            check=False,
        )
        if result.returncode:
            continue  # The device may have disappeared during enumeration.

        properties = dict(
            line.split("=", 1)
            for line in result.stdout.splitlines()
            if "=" in line
        )
        if properties.get("ID_INPUT_TOUCHSCREEN") != "1":
            continue
        # Do not exclusively grab a combined keyboard or pointing device.
        if any(properties.get(key) == "1" for key in (
            "ID_INPUT_KEYBOARD", "ID_INPUT_TOUCHPAD", "ID_INPUT_MOUSE"
        )):
            continue
        try:
            device = os.stat(path)
            # Event numbers and device numbers may be reused after hotplug.
            nodes[path] = (device.st_dev, device.st_ino, device.st_rdev)
        except FileNotFoundError:
            continue
    return nodes


def grab(path, expected_identity):
    fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_CLOEXEC)
    try:
        device = os.fstat(fd)
        if (device.st_dev, device.st_ino, device.st_rdev) != expected_identity:
            raise OSError("input device changed during enumeration")
        fcntl.ioctl(fd, EVIOCGRAB, 1)
    except BaseException:
        os.close(fd)
        raise
    return fd


def run():
    if os.geteuid() != 0:
        report("ERROR Touch Guard helper must run through pkexec")
        return 1

    held = {}  # path -> (device identity, file descriptor)
    selector = selectors.DefaultSelector()
    selector.register(sys.stdin.buffer, selectors.EVENT_READ)
    announced = None
    try:
        while True:
            wanted = touchscreen_nodes()
            for path, (device_identity, fd) in list(held.items()):
                if wanted.get(path) != device_identity:
                    os.close(fd)
                    del held[path]

            for path, device_identity in wanted.items():
                if path not in held:
                    held[path] = (device_identity,
                                  grab(path, device_identity))

            state = ("READY", len(held)) if held else ("WAITING", 0)
            if state != announced:
                report(f"{state[0]} {state[1]}")
                announced = state

            if selector.select(SCAN_INTERVAL):
                # The extension retains stdin while guarded. EOF releases all
                # grabs, including when GNOME Shell exits unexpectedly.
                if not os.read(sys.stdin.fileno(), 1):
                    return 0
    except (OSError, subprocess.TimeoutExpired) as error:
        report(f"ERROR {error}")
        return 1
    finally:
        selector.close()
        for _, fd in held.values():
            os.close(fd)


if __name__ == "__main__":
    try:
        sys.exit(run())
    except BrokenPipeError:
        sys.exit(0)
