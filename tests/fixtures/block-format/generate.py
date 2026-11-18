# Regenerate: python3 tests/fixtures/block-format/generate.py tests/fixtures/block-format
# Independent reference implementation of docs/block-format.md (the fixtures are not produced by the
# CFML or TypeScript code they test).
"""Independent reference for docs/block-format.md: writes tests/fixtures/block-format/*.json."""
import json
import pathlib
import sys

OUT = pathlib.Path(sys.argv[1])


def jhash(s: str) -> str:
    raw = s.encode("utf-16-le")
    h = 0
    for i in range(0, len(raw), 2):
        h = (31 * h + int.from_bytes(raw[i:i + 2], "little")) & 0xFFFFFFFF
    return f"{h:08x}"


def esc(js: str) -> str:
    return (js.replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
              .replace("--", "\\u002d\\u002d").replace("{{", "\\u007b\\u007b"))


def marker(type_, id_, data, html, v=1, hash_=True, hash_value=None):
    env = {"type": type_, "v": v, "id": id_}
    if hash_:
        env["hash"] = hash_value or jhash(html)
    env["data"] = {} if type_ == "html" else data
    js = esc(json.dumps(env, ensure_ascii=False, separators=(",", ":")))
    return f"<!-- cb:block {js} -->\n{html}\n<!-- /cb:block -->"


def parsed(type_, id_, data, html, status="ok", v=1):
    d = dict(data)
    if type_ == "html":
        d["html"] = html
    return {"type": type_, "v": v, "id": id_, "data": d, "html": html, "status": status}


def legacy(n, html, status="legacy"):
    return {"type": "html", "v": 1, "id": f"legacy-{n}", "data": {"html": html}, "html": html, "status": status}


def write(name, description, body, blocks, serialized=None):
    fixture = {"description": description, "body": body, "blocks": blocks}
    if serialized is not None:
        fixture["serialized"] = serialized
    (OUT / f"{name}.json").write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def neutralize(html):
    import re
    return re.sub(r"<!--(\s*/?)cb:block", r"<!--\1cb-block", html)


def ser(blocks):
    return "\n\n".join(marker(b["type"], b["id"], {k: v for k, v in b["data"].items()}, neutralize(b["html"]), b["v"]) for b in blocks)


OUT.mkdir(parents=True, exist_ok=True)

heading_data = {"text": "Rooms", "level": "2"}
heading_html = '<h2 class="cbs-heading">Rooms</h2>'
text_data = {"content": {"type": "doc", "content": [{"type": "paragraph", "content": [{"type": "text", "text": "Sea view"}]}]}}
text_html = '<div class="cbs-text"><p>Sea view</p></div>'
html_html = "<p>Any <strong>HTML</strong></p>"

write("01-empty", "An empty body has no blocks", "", [], "")
write("02-whitespace", "A body with only whitespace has no blocks", "  \n\n\t \r\n", [], "")

b = legacy(1, "<p>Hello</p>\n<p>World</p>")
write("03-plain-html", "A body without markers is one legacy block, trimmed", "\n<p>Hello</p>\n<p>World</p>\n", [b], ser([b]))

b = parsed("heading", "k2f9a", heading_data, heading_html)
body = marker("heading", "k2f9a", heading_data, heading_html)
write("04-single-block", "One block", body, [b], body)

blocks = [
    parsed("heading", "k2f9a", heading_data, heading_html),
    parsed("text", "p0q1r", text_data, text_html),
    parsed("html", "x81qe", {}, html_html),
]
body = ser(blocks)
write("05-multiple-blocks", "Several blocks round-trip byte for byte; html blocks keep their HTML only once", body, blocks, body)

first = parsed("heading", "k2f9a", heading_data, heading_html)
last = parsed("text", "p0q1r", text_data, text_html)
stray = "<p>added outside Studio</p>"
body = marker("heading", "k2f9a", heading_data, heading_html) + "\n\n" + stray + "\n\n" + marker("text", "p0q1r", text_data, text_html)
blocks = [first, legacy(1, stray), last]
write("06-stray-html", "Text between blocks becomes a legacy block in its place", body, blocks, ser(blocks))

edited = '<h2 class="cbs-heading">Rooms and suites</h2>'
body = marker("heading", "k2f9a", heading_data, edited, hash_value=jhash(heading_html))
blocks = [parsed("heading", "k2f9a", heading_data, edited, status="modified")]
write("07-modified", "Inner HTML changed outside Studio: hash mismatch", body, blocks, ser(blocks))

tricky = 'Close </script> --> & {{{ContentStore slug="x"}}} "quoted" \\ back\\slash Ümläute 🎉 ---'
data = {"text": tricky, "level": "3"}
html = '<h3 class="cbs-heading">Close &lt;/script&gt; --&gt; &amp; {{{ContentStore slug=&quot;x&quot;}}} &quot;quoted&quot; \\ back\\slash Ümläute 🎉 ---</h3>'
body = marker("heading", "e5c4p", data, html)
blocks = [parsed("heading", "e5c4p", data, html)]
write("08-escaping", "Characters that would end the comment or trigger ContentBox renderers are escaped in the JSON", body, blocks, body)

body = '<!-- cb:block {"type":"heading","v":1,"id":"bad1","data":{"text":"Bro -->\n<h2>Broken</h2>\n<!-- /cb:block -->'
blocks = [legacy(1, "<h2>Broken</h2>", status="invalid")]
write("09-invalid-json", "An envelope that is not valid JSON keeps its inner HTML as an invalid html block", body, blocks, ser(blocks))

ok = marker("heading", "k2f9a", heading_data, heading_html)
rest = '<!-- cb:block {"type":"text","v":1,"id":"open1","data":{}} -->\n<p>no closing marker</p>'
body = ok + "\n\n" + rest
blocks = [parsed("heading", "k2f9a", heading_data, heading_html), legacy(1, rest)]
write("10-unclosed", "An opening marker without a closing one: the rest of the body is one legacy block", body, blocks, ser(blocks))

env = {"type": "heading", "v": 1, "id": "nohash", "data": heading_data}
body = f"<!-- cb:block {esc(json.dumps(env, separators=(',', ':')))} -->\n{heading_html}\n<!-- /cb:block -->"
blocks = [parsed("heading", "nohash", heading_data, heading_html)]
write("11-no-hash", "A block without hash is trusted", body, blocks, ser(blocks))

body = marker("heading", "k2f9a", heading_data, heading_html).replace("\n", "\r\n")
blocks = [parsed("heading", "k2f9a", heading_data, heading_html)]
write("12-crlf", "CRLF line breaks around the inner HTML are not part of it", body, blocks, ser(blocks))

inner_open = '<!-- cb:block {"type":"text","v":1,"id":"in1","data":{}} -->'
body = '<!-- cb:block {"type":"text","v":1,"id":"out1","data":{}} -->\n<p>a</p>\n' + inner_open + "\n<p>b</p>\n<!-- /cb:block -->"
blocks = [legacy(1, body)]
write("13-nested", "A second opening marker before the closing one: the rest of the body is one legacy block", body, blocks, ser(blocks))

v2 = {"type": "textSection", "v": 2, "id": "Ts_01", "hash": jhash("<section>x</section>"), "data": {"heading": "x"}, "extra": True}
body = f"<!-- cb:block {esc(json.dumps(v2, separators=(',', ':')))} -->\n<section>x</section>\n<!-- /cb:block -->"
blocks = [parsed("textSection", "Ts_01", {"heading": "x"}, "<section>x</section>", v=2)]
write("14-version-and-unknown-keys", "Block type versions are kept, unknown envelope keys ignored", body, blocks, ser(blocks))

print("written", len(list(OUT.glob("*.json"))), "fixtures")
