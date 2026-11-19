#!/usr/bin/env python3
"""AirPods over Apple's AAP control channel (L2CAP PSM 0x1001).

  bridge.py scan           paired Apple headphones, as JSON
  bridge.py watch <addr>   connect, then print one JSON state per line as it
                           changes; reads commands on stdin:
                             noise <1-4>   off / noise cancellation /
                                           transparency / adaptive
                             ca <0|1>      conversational awareness

The packet layout follows LibrePods' notes on the protocol
(github.com/kavishdevar/librepods, AAP Definitions). Only standard library.
"""

import json
import os
import re
import select
import socket
import subprocess
import sys

PSM = 0x1001

HANDSHAKE = bytes.fromhex("00000400010002000000000000000000")
# Turns on the newer features (conversational awareness, adaptive).
FEATURES = bytes.fromhex("040004004d00ff0000000000000000")
NOTIFY = bytes.fromhex("040004000f00fffffeff")

HEADER = bytes.fromhex("04000400")
OP_BATTERY = 0x04
OP_EAR = 0x06
OP_CONTROL = 0x09

CONTROL_NOISE = 0x0D
CONTROL_CA = 0x28

# Product ids from the modalias (bluetooth:v004Cp<id>...). Only used for a
# friendly model name and whether Adaptive is offered; everything else comes
# from what the AirPods report.
MODELS = {
    0x2002: ("AirPods", False),
    0x200F: ("AirPods (2nd generation)", False),
    0x2013: ("AirPods (3rd generation)", False),
    0x2019: ("AirPods 4", False),
    0x201B: ("AirPods 4 (ANC)", True),
    0x200E: ("AirPods Pro", False),
    0x2014: ("AirPods Pro 2", True),
    0x2024: ("AirPods Pro 2 (USB-C)", True),
    0x200A: ("AirPods Max", False),
    0x201F: ("AirPods Max (USB-C)", False),
}

COMPONENTS = {0x01: "single", 0x02: "right", 0x04: "left", 0x08: "case"}
EAR = {0x00: "ear", 0x01: "out", 0x02: "case"}


def bluetoothctl(*args):
    try:
        return subprocess.run(["bluetoothctl", *args], capture_output=True,
                              text=True, timeout=5).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def scan():
    devices = []
    for line in bluetoothctl("devices", "Paired").splitlines():
        match = re.match(r"Device ([0-9A-F:]{17}) (.*)", line.strip())
        if not match:
            continue
        address, name = match.groups()
        info = bluetoothctl("info", address)
        modalias = re.search(r"Modalias: bluetooth:v004Cp([0-9A-F]{4})", info, re.I)
        if not modalias:
            continue
        product = int(modalias.group(1), 16)
        model, adaptive = MODELS.get(product, ("AirPods", None))
        # Apple keyboards, mice and phones share the vendor id: keep only
        # what plays audio.
        if product not in MODELS and "0000110b-" not in info:
            continue
        devices.append({"address": address.upper(), "name": name, "model": model,
                        "product": product, "adaptive": adaptive})
    print(json.dumps({"devices": devices}))


def parse(packet, state):
    """Fold one packet into state. True when something changed."""
    if len(packet) < 6 or packet[:4] != HEADER:
        return False
    op = packet[4]

    if op == OP_BATTERY and len(packet) >= 7:
        battery = {}
        count = packet[6]
        for i in range(count):
            at = 7 + i * 5
            if at + 4 > len(packet):
                break
            kind, level, status = packet[at], packet[at + 2], packet[at + 3]
            name = COMPONENTS.get(kind)
            # 0x04: that part is not connected (a pod in a closed case).
            if name is None or status == 0x04 or level > 100:
                continue
            battery[name] = {"level": level, "charging": status == 0x01}
        if battery != state.get("battery"):
            state["battery"] = battery
            return True
        return False

    if op == OP_EAR and len(packet) >= 8:
        ear = [EAR.get(packet[6], "unknown"), EAR.get(packet[7], "unknown")]
        if ear != state.get("ear"):
            state["ear"] = ear
            return True
        return False

    if op == OP_CONTROL and len(packet) >= 8:
        control, value = packet[6], packet[7]
        if control == CONTROL_NOISE and 1 <= value <= 4:
            if state.get("noise") != value:
                state["noise"] = value
                return True
        elif control == CONTROL_CA and value in (1, 2):
            if state.get("ca") != (value == 1):
                state["ca"] = value == 1
                return True
    return False


def control(sock, kind, value):
    sock.send(HEADER + bytes([OP_CONTROL, 0x00, kind, value, 0, 0, 0]))


def watch(address):
    if not re.fullmatch(r"([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", address):
        sys.exit("not a Bluetooth address")
    try:
        sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_SEQPACKET, socket.BTPROTO_L2CAP)
        sock.settimeout(8)
        sock.connect((address, PSM))
        sock.settimeout(None)
        for packet in (HANDSHAKE, FEATURES, NOTIFY):
            sock.send(packet)
    except OSError as error:
        sys.exit(f"Could not open the AirPods control channel: {error.strerror or error}")

    state = {"connected": True}
    print(json.dumps(state), flush=True)

    stdin = sys.stdin.fileno()
    buffered = b""
    watching = [sock, stdin]
    while True:
        ready, _, _ = select.select(watching, [], [])
        if sock in ready:
            try:
                packet = sock.recv(1024)
            except OSError:
                packet = b""
            if not packet:
                sys.exit("The AirPods closed the control channel")
            if parse(packet, state):
                print(json.dumps(state), flush=True)
        if stdin in ready:
            chunk = os.read(stdin, 1024)
            if not chunk:
                # The shell went away; nothing left to listen for.
                watching = [sock]
                continue
            buffered += chunk
            while b"\n" in buffered:
                line, buffered = buffered.split(b"\n", 1)
                parts = line.decode(errors="replace").split()
                try:
                    if len(parts) == 2 and parts[0] == "noise" and parts[1] in "1234":
                        control(sock, CONTROL_NOISE, int(parts[1]))
                        state["noise"] = int(parts[1])
                        print(json.dumps(state), flush=True)
                    elif len(parts) == 2 and parts[0] == "ca" and parts[1] in ("0", "1"):
                        control(sock, CONTROL_CA, 1 if parts[1] == "1" else 2)
                        state["ca"] = parts[1] == "1"
                        print(json.dumps(state), flush=True)
                except OSError as error:
                    sys.exit(f"Could not send to the AirPods: {error.strerror or error}")


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "scan":
        scan()
    elif len(sys.argv) == 3 and sys.argv[1] == "watch":
        watch(sys.argv[2])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
