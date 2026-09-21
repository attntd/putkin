"""Linux process ownership shared by the Signal bridge and its exec shim."""
import ctypes
import os
import signal
import sys


def parent_death(expected_parent, death_signal):
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(1, death_signal, 0, 0, 0) != 0:  # PR_SET_PDEATHSIG
        raise OSError(ctypes.get_errno(), "parent_death_unavailable")
    # Covers death between spawn and prctl. Never use a stored PID to kill.
    if os.getppid() != expected_parent:
        os.kill(os.getpid(), death_signal)


def child_command(command):
    return [sys.executable, "-B", os.path.abspath(__file__), str(os.getpid()), *command]


if __name__ == "__main__":
    try:
        parent_death(int(sys.argv[1]), signal.SIGKILL)
        # pass_fds preserves only owner.lock in addition to the stdio pipes.
        # No fork here: the pinned CLI wrapper must exec the JVM in this PID.
        os.execvpe(sys.argv[2], sys.argv[2:], os.environ)
    except (OSError, ValueError, IndexError):
        os._exit(127)  # No argv, paths, payloads or exception text in logs.
