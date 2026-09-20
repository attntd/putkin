"""Production bridge with shorter deadlines on private fixture buses."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "services"))
from session_backend import SessionBackend, main
from session_dbus_fake import isolated


class FixtureBackend(SessionBackend):
    lock_timeout_ms = 600
    action_timeout = 0.5



if __name__ == "__main__":
    isolated()
    main(FixtureBackend)
