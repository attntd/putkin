#!/usr/bin/env python3
"""Assuan frontend for existing GPG keys/cards, with explicit capability errors."""
import os
import sys
from urllib.parse import unquote_to_bytes
from auth_client import Cancelled, harden, request

CANCELLED = "ERR 83886179 Operation cancelled"
NOT_CONFIRMED = "ERR 83886194 Not confirmed"
UNSUPPORTED = "ERR 83886140 Not supported"
UNKNOWN = "ERR 83886355 Unknown IPC command"
PARAMETER = "ERR 83886360 Invalid parameter"


def decode(value):
    return unquote_to_bytes(value).decode("utf-8", errors="strict")


def escape(value):
    return value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def label(value):
    return value.replace("__", "\0").replace("_", "").replace("\0", "_")


def run(input_stream, output, ask=request):
    state = {}
    forbidden = False
    timeout = 0
    def emit(value):
        output.write(value + "\n")
        output.flush()
    emit("OK Putkin Pinentry ready")
    while True:
        raw = input_stream.readline(16385)
        if not raw:
            return
        if len(raw) > 16384:
            emit(PARAMETER)
            return
        raw = raw.rstrip("\r\n")
        if not raw or raw.startswith("#"):
            continue
        command, _, argument = raw.partition(" ")
        command = command.upper()
        try:
            value = decode(argument)
            if "\0" in value:
                raise ValueError("NUL")
            if command == "BYE":
                emit("OK")
                return
            if command == "RESET":
                state = {}; forbidden = False; timeout = 0
            elif command == "NOP":
                pass
            elif command == "SETTIMEOUT":
                timeout = int(value)
                if not 0 <= timeout <= 86400:
                    raise ValueError("timeout")
            elif command in ("SETDESC", "SETPROMPT", "SETTITLE", "SETERROR", "SETOK", "SETCANCEL", "SETNOTOK", "SETKEYINFO"):
                if len(value) > 8192:
                    raise ValueError("size")
                state[command] = value
            elif command in ("SETREPEAT", "SETREPEATERROR", "SETREPEATOK", "SETGENPIN", "SETGENPIN_TT"):
                forbidden = True
                emit(UNSUPPORTED)
                continue
            elif command in ("SETQUALITYBAR", "SETQUALITYBAR_TT"):
                emit(UNSUPPORTED)
                continue
            elif command == "OPTION":
                name, _, option = value.partition("=")
                if name in ("constraints-enforce", "formatted-passphrase"):
                    forbidden = True
                    emit(UNSUPPORTED)
                    continue
                if name in ("ttyname", "ttytype", "lc-ctype", "lc-messages", "display", "parent-wid", "grab", "no-grab", "allow-external-password-cache", "default-ok", "default-cancel", "default-notok", "default-prompt", "touch-file", "owner", "invisible-char", "formatted-passphrase-hint"):
                    # No external cache. Default translations do not replace
                    # the user's approved copy; explicit SET* semantics do.
                    pass
                else:
                    emit(UNSUPPORTED)
                    continue
            elif command == "GETINFO":
                info = {"pid": str(os.getpid()), "version": "1.0", "flavor": "putkin"}
                if value not in info:
                    emit(UNSUPPORTED)
                    continue
                emit("D " + info[value])
            elif command in ("GETPIN", "CONFIRM", "MESSAGE"):
                if forbidden:
                    emit(UNSUPPORTED)
                    continue
                if argument and not (command == "CONFIRM" and argument == "--one-button"):
                    emit(UNSUPPORTED)
                    continue
                mode = "input" if command == "GETPIN" else "message" if command == "MESSAGE" or argument == "--one-button" else "confirm"
                description = state.get("SETDESC", "")
                if state.get("SETTITLE"):
                    description = state["SETTITLE"] + "\n" + description
                payload = {"source": "gpg", "mode": mode, "message": description,
                           "prompt": label(state.get("SETPROMPT", "")),
                           "error": state.pop("SETERROR", ""), "accept": label(state.get("SETOK", "")),
                           "reject": label(state.get("SETNOTOK", ""))}
                try:
                    result = ask(payload, timeout)
                except (Cancelled, OSError, ValueError, KeyError):
                    emit(CANCELLED)
                    continue
                if not result["accepted"]:
                    emit(NOT_CONFIRMED if result.get("rejected") else CANCELLED)
                    continue
                if command == "GETPIN":
                    if "\0" in result["response"]:
                        emit(PARAMETER)
                        continue
                    # Escape each chunk separately: never split a %XX escape
                    # or a UTF-8 character across Assuan data records.
                    for offset in range(0, len(result["response"]), 64):
                        emit("D " + escape(result["response"][offset:offset + 64]))
                result = None
            else:
                emit(UNKNOWN)
                continue
            emit("OK")
        except (ValueError, UnicodeError):
            emit(PARAMETER)


def main():
    try:
        harden()
        run(sys.stdin, sys.stdout)
        return 0
    except (Cancelled, OSError):
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
