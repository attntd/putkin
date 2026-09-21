"""In-memory QR modules; no child command, URI in argv, files, or image cache."""
import ctypes
from urllib.parse import parse_qs, urlsplit

from signal_transport import Failure


class Code(ctypes.Structure):
    _fields_ = [("version", ctypes.c_int), ("width", ctypes.c_int),
                ("data", ctypes.POINTER(ctypes.c_ubyte))]


def library():
    try:
        lib = ctypes.CDLL("libqrencode.so.4")
    except OSError:
        raise Failure("qr_unavailable") from None
    lib.QRcode_encodeString8bit.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_int]
    lib.QRcode_encodeString8bit.restype = ctypes.POINTER(Code)
    lib.QRcode_free.argtypes = [ctypes.POINTER(Code)]
    lib.QRcode_free.restype = None
    return lib


def modules(uri):
    if not isinstance(uri, str) or len(uri) > 2048 or any(ord(c) < 33 or ord(c) > 126 for c in uri):
        raise Failure("invalid_link")
    try:
        parts = urlsplit(uri)
        params = parse_qs(parts.query, strict_parsing=True)
        if (parts.scheme != "sgnl" or parts.netloc != "linkdevice" or parts.path or parts.fragment
                or not {"uuid", "pub_key"} <= set(params) or set(params) - {"uuid", "pub_key", "capabilities"}
                or any(len(v) != 1 or not v[0] for v in params.values())):
            raise ValueError()
    except ValueError:
        raise Failure("invalid_link") from None
    lib = library()
    code = lib.QRcode_encodeString8bit(uri.encode("ascii"), 0, 1)  # QR ECC M.
    if not code:
        raise Failure("qr_error")
    try:
        width = code.contents.width
        if not 21 <= width <= 177:
            raise Failure("qr_error")
        data = code.contents.data
        return ["".join("1" if data[y * width + x] & 1 else "0" for x in range(width)) for y in range(width)]
    finally:
        lib.QRcode_free(code)
