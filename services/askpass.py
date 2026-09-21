#!/usr/bin/env python3
"""OpenSSH and sudo -A frontend; the caller alone verifies the response."""
import os
import sys
from auth_client import Cancelled, harden, request


def main():
    try:
        harden()
        mode = os.environ.get("SSH_ASKPASS_PROMPT", "input")
        mode = mode if mode in ("none", "confirm") else "input"
        message = sys.argv[1] if len(sys.argv) > 1 else ""
        if len(message) > 8192:
            return 1
        source = "sudo" if os.environ.get("SUDO_COMMAND") else "ssh"
        result = request({"source": source, "mode": mode, "message": message, "prompt": ""})
        if mode == "none" or not result["accepted"]:
            return 1
        response = result["response"]
        if any(char in response for char in "\r\n\0"):
            return 1
        sys.stdout.write(response + "\n")
        sys.stdout.flush()
        return 0
    except (Cancelled, OSError, ValueError, KeyError):
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
