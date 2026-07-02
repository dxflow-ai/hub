#!/usr/bin/env python3
# Stream the desktop's PulseAudio output to the browser as raw PCM over a
# WebSocket on AUDIO_PORT (default 6100) — a dependency-free port of the Go proxy.
# parec records the default sink monitor; each connected client toggles the
# stream with "start"/"stop" text messages; fully silent chunks are skipped.

from __future__ import annotations

import base64
import hashlib
import os
import socket
import subprocess
import threading
from collections.abc import Iterator
from typing import IO

HOST = "0.0.0.0"
PORT = int(os.environ.get("AUDIO_PORT", "6100"))
WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

CHANNELS = 2 if os.environ.get("AUDIO_CHANNELS") == "2" else 1
RATE = {"8000": 8000, "16000": 16000, "32000": 32000, "44100": 44100}.get(
    os.environ.get("AUDIO_RATE", ""), 22050
)

clients: dict[socket.socket, bool] = {}
clients_lock = threading.Lock()


def handshake(conn: socket.socket) -> bool:
    data = b""
    while b"\r\n\r\n" not in data:
        chunk = conn.recv(1024)
        if not chunk:
            return False
        data += chunk

    key = ""
    for line in data.split(b"\r\n"):
        if line.lower().startswith(b"sec-websocket-key:"):
            key = line.split(b":", 1)[1].strip().decode()

    accept = base64.b64encode(hashlib.sha1((key + WS_GUID).encode()).digest()).decode()
    _ = conn.send(
        b"HTTP/1.1 101 Switching Protocols\r\n"
        + b"Upgrade: websocket\r\n"
        + b"Connection: Upgrade\r\n"
        + b"Sec-WebSocket-Accept: "
        + accept.encode()
        + b"\r\n\r\n"
    )
    return True


def encode_binary(payload: bytes) -> bytes:
    header = bytearray([0x82])  # FIN + binary opcode
    length = len(payload)
    if length < 126:
        header.append(length)
    elif length < 65536:
        header.append(126)
        header += length.to_bytes(2, "big")
    else:
        header.append(127)
        header += length.to_bytes(8, "big")
    return bytes(header) + payload


def read_control(conn: socket.socket) -> Iterator[str]:
    # Yield client text messages ("start"/"stop"); stop on close or error.
    buffer = b""

    def recv_exact(count: int) -> bytes | None:
        nonlocal buffer
        while len(buffer) < count:
            chunk = conn.recv(4096)
            if not chunk:
                return None
            buffer += chunk
        head, buffer = buffer[:count], buffer[count:]
        return head

    while True:
        head = recv_exact(2)
        if head is None:
            return
        opcode = head[0] & 0x0F
        masked = bool(head[1] & 0x80)
        length = head[1] & 0x7F
        if length == 126:
            extended = recv_exact(2)
            if extended is None:
                return
            length = int.from_bytes(extended, "big")
        elif length == 127:
            extended = recv_exact(8)
            if extended is None:
                return
            length = int.from_bytes(extended, "big")
        if masked:
            mask = recv_exact(4)
            if mask is None:
                return
        else:
            mask = b"\x00\x00\x00\x00"
        payload = recv_exact(length) if length else b""
        if payload is None:
            return
        if masked:
            payload = bytes(
                byte ^ mask[index % 4] for index, byte in enumerate(payload)
            )
        if opcode == 0x8:  # close
            return
        if opcode == 0x1:  # text
            yield payload.decode(errors="ignore")


def serve_client(conn: socket.socket) -> None:
    if not handshake(conn):
        conn.close()
        return
    with clients_lock:
        clients[conn] = False
    try:
        for message in read_control(conn):
            if message == "start":
                with clients_lock:
                    clients[conn] = True
            elif message == "stop":
                with clients_lock:
                    clients[conn] = False
    finally:
        with clients_lock:
            _ = clients.pop(conn, None)
        conn.close()


def broadcaster() -> None:
    parec = subprocess.Popen(
        [
            "parec",
            "--format=s16le",
            "--device=@DEFAULT_MONITOR@",
            "--latency=1024",
            "--process-time=1024",
            "--channels=%d" % CHANNELS,
            "--rate=%d" % RATE,
        ],
        stdout=subprocess.PIPE,
    )
    stream: IO[bytes] | None = parec.stdout
    if stream is None:
        return
    while True:
        chunk = stream.read(1024)
        if not chunk:
            break
        if not any(chunk):  # skip fully silent chunks
            continue
        frame = encode_binary(chunk)
        with clients_lock:
            targets = [conn for conn, listening in clients.items() if listening]
        for conn in targets:
            try:
                conn.sendall(frame)
            except OSError:
                pass


def main() -> None:
    threading.Thread(target=broadcaster, daemon=True).start()

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((HOST, PORT))
    server.listen(64)

    while True:
        conn = server.accept()[0]
        threading.Thread(target=serve_client, args=(conn,), daemon=True).start()


if __name__ == "__main__":
    main()
