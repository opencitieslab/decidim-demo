"""Quick per-chunk check used by translation agents (plan U3).

    python -I script/i18n/check_chunk.py SOURCE_CHUNK.json TRANSLATED.json

Mirrors the rules in common.rb: same keys, identical %{..}/%<..>s
placeholders, identical strftime tokens, identical HTML tag names, no empty
values. Exit code 0 when clean. Also prints how many values were left
identical to English (a hint, not a failure).
"""
import json
import re
import sys

INTERP = re.compile(r"%\{[^}]+\}|%<[^>]+>[-+ 0#]*\d*(?:\.\d+)?[a-zA-Z]")
STRF = re.compile(r"%[-_0^#:]?[a-zA-Z](?![a-zA-Z])")
TAG = re.compile(r"</?([a-zA-Z][a-zA-Z0-9-]*)\b[^<>]*>")


def interps(s):
    return sorted(INTERP.findall(s))


def strf(s):
    return sorted(STRF.findall(INTERP.sub("", s)))


def tags(s):
    return sorted(t.lower() for t in TAG.findall(s))


def main(src_path, out_path):
    with open(src_path, encoding="utf-8") as f:
        src = json.load(f)
    try:
        with open(out_path, encoding="utf-8") as f:
            out = json.load(f)
    except Exception as e:  # noqa: BLE001
        print("INVALID JSON: %s" % e)
        return 1
    problems = []
    missing = [k for k in src if k not in out]
    extra = [k for k in out if k not in src]
    for k in missing:
        problems.append("%s: missing" % k)
    for k in extra:
        problems.append("%s: extra key" % k)
    same = 0
    for k, en in src.items():
        if k not in out:
            continue
        tr = out[k]
        if not isinstance(tr, str):
            problems.append("%s: not a string" % k)
            continue
        if not tr.strip():
            problems.append("%s: empty" % k)
        if interps(en) != interps(tr):
            problems.append("%s: placeholders %s != %s" % (k, interps(en), interps(tr)))
        if strf(en) != strf(tr):
            problems.append("%s: format tokens %s != %s" % (k, strf(en), strf(tr)))
        if tags(en) != tags(tr):
            problems.append("%s: html tags %s != %s" % (k, tags(en), tags(tr)))
        if tr == en and len(en) > 12:
            same += 1
    for p in problems:
        print(p)
    print("%d keys, %d problems, %d long values identical to English" % (len(src), len(problems), same))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))
