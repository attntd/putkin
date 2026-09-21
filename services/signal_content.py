"""Bounded plain text, UTF-16 ranges and typed quote metadata; never sender HTML."""
from signal_events import integer, service_id, text
from signal_transport import Failure

STYLES = {'BOLD', 'ITALIC', 'SPOILER', 'STRIKETHROUGH', 'MONOSPACE'}
# Curated composer choices; preserve exact sequences (VS16/ZWJ/skin tones).
EMOJI = ('👍', '❤️', '😂', '😮', '😢', '🙏', '🎉', '👎', '👩\u200d💻', '👍🏽')


def emoji(value):
    value = text(value, 128, empty=False)
    points = list(map(ord, value))
    def base(cp):
        return (0x1f000 <= cp <= 0x1faff and not 0x1f3fb <= cp <= 0x1f3ff) or 0x2100 <= cp <= 0x2bff or cp in (0xa9, 0xae, 0x203c, 0x2049, 0x2122, 0x2139, 0x3030, 0x303d, 0x3297, 0x3299)
    if all(0x1f1e6 <= c <= 0x1f1ff for c in points):
        valid = len(points) == 2
    elif value[0] in '0123456789#*':
        valid = points[1:] in ([0x20e3], [0xfe0f, 0x20e3])
    else:
        need_base, valid = True, True
        for cp in points:
            if need_base:
                if not base(cp) or 0x1f1e6 <= cp <= 0x1f1ff: valid = False; break
                need_base = False
            elif cp == 0x200d:
                need_base = True
            elif cp not in (0xfe0e, 0xfe0f) and not 0x1f3fb <= cp <= 0x1f3ff and not 0xe0020 <= cp <= 0xe007f:
                valid = False; break
        valid = valid and not need_base
    if not valid:
        raise Failure('invalid_reaction')
    return value


def ranges(body, values, *, mentions=False):
    if not isinstance(values, list) or len(values) > 100:
        raise Failure('invalid_request')
    # Valid offsets may not bisect a surrogate pair. Python indexes code points.
    boundaries, offset = {0}, 0
    for char in body:
        offset += 2 if ord(char) > 0xffff else 1
        boundaries.add(offset)
    result, occupied = [], set()
    for value in values:
        start, length = integer(value['start']), integer(value['length'], minimum=1)
        if start not in boundaries or start + length not in boundaries:
            raise Failure('invalid_range')
        item = {'start': start, 'length': length}
        if mentions:
            sid = service_id(value.get('serviceId') or value.get('uuid'))
            if not sid.startswith('aci:') or occupied.intersection(range(start, start + length)):
                raise Failure('invalid_range')
            occupied.update(range(start, start + length))
            item['serviceId'] = sid
        else:
            if value.get('style') not in STYLES:
                continue  # Unknown future styles have a plain-text fallback.
            item['style'] = value['style']
        if item not in result:
            result.append(item)
    return result


def metadata(data, body):
    result = {'mentions': ranges(body or '', data.get('mentions') or [], mentions=True),
              'styles': ranges(body or '', data.get('textStyles') or [])}
    quote = data.get('quote')
    if quote:
        # A missing ACI cannot safely navigate to an unrelated number-only row.
        result['quote'] = {'timestampMs': integer(quote['id'], minimum=1),
                           'authorServiceId': service_id(quote['authorUuid']) if quote.get('authorUuid') else '',
                           'text': text(quote.get('text') or '')}
    return result


def send_fields(meta):
    result = {}
    if meta.get('mentions'):
        result['mention'] = [f"{m['start']}:{m['length']}:{m['serviceId'].removeprefix('aci:')}" for m in meta['mentions']]
    if meta.get('styles'):
        result['textStyle'] = [f"{m['start']}:{m['length']}:{m['style']}" for m in meta['styles']]
    quote = meta.get('quote')
    if quote and quote['authorServiceId']:
        result.update(quoteTimestamp=quote['timestampMs'], quoteAuthor=quote['authorServiceId'].removeprefix('aci:'), quoteMessage=quote['text'])
    return result
