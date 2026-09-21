"""Independent ZXing decoder, test-only. Pixels and decoded value stay in RAM."""
import ctypes as c


def decode(rows):
    lib = c.CDLL("libZXing.so.4")
    def function(name, result, args):
        fn = getattr(lib, "ZXing_" + name)
        fn.restype, fn.argtypes = result, args
        return fn
    ptr, integer = c.c_void_p, c.c_int
    image_new = function("ImageView_new", ptr, [ptr, integer, integer, integer, integer, integer])
    image_delete = function("ImageView_delete", None, [ptr])
    options_new = function("ReaderOptions_new", ptr, [])
    options_delete = function("ReaderOptions_delete", None, [ptr])
    read = function("ReadBarcodes", ptr, [ptr, ptr])
    size = function("Barcodes_size", integer, [ptr])
    at = function("Barcodes_at", ptr, [ptr, integer])
    content = function("Barcode_text", ptr, [ptr])
    delete = function("Barcodes_delete", None, [ptr])
    free = function("free", None, [ptr])
    width = len(rows)
    raw = bytes(0 if pixel == "1" else 255 for row in rows for pixel in row)
    pixels = c.create_string_buffer(raw)
    image = image_new(pixels, width, width, 0x01000000, width, 1)
    options = options_new()
    codes = read(image, options)
    try:
        if size(codes) != 1:
            raise AssertionError("QR did not decode to exactly one symbol")
        value = content(at(codes, 0))
        try:
            return c.string_at(value).decode()
        finally:
            free(value)
    finally:
        delete(codes)
        options_delete(options)
        image_delete(image)


def render(modules, scale=4):
    # Four modules of quiet zone, the same scan geometry as SignalQr.qml.
    blank = "0" * (len(modules) + 8)
    rows = [blank] * 4 + ["0000" + row + "0000" for row in modules] + [blank] * 4
    return ["".join(pixel * scale for pixel in row) for row in rows for _ in range(scale)]
