#!/usr/bin/env python3
"""Turns `tmux capture-pane -e -p` output into an HTML page that looks like a terminal.
Usage: ansi2html.py capture.txt > frame.html"""
import html, re, sys, unicodedata

DEFAULT_FG, DEFAULT_BG = "#d0d0d0", "#14151b"
BASE = ["#1c1c1c", "#e05561", "#8cc265", "#d18f52", "#4aa5f0", "#c162de", "#42b3c2", "#d0d0d0",
        "#5c6370", "#ff616e", "#a5e075", "#f0a45d", "#4dc4ff", "#de73ff", "#4cd1e0", "#ffffff"]

# drawn as CSS circles so the render does not depend on an emoji font
DOTS = {"🟡": "#ffd21f", "🟢": "#2fd655", "🔴": "#ff4040"}

def xterm(n):
    if n < 16:
        return BASE[n]
    if n < 232:
        n -= 16
        steps = [0, 95, 135, 175, 215, 255]
        return "#%02x%02x%02x" % (steps[n // 36], steps[(n // 6) % 6], steps[n % 6])
    v = 8 + (n - 232) * 10
    return "#%02x%02x%02x" % (v, v, v)

def wide(ch):
    return unicodedata.east_asian_width(ch) in "WF" or ord(ch) >= 0x1F000

def convert(text):
    out, st = [], {"fg": None, "bg": None, "bold": False, "rev": False}
    tok = re.compile(r"\x1b\[([0-9;]*)m|\x1b\][^\x07]*\x07|\x1b[()][A-Z0-9]|(.)", re.S)
    run, run_style = [], None

    def style():
        fg, bg = st["fg"] or DEFAULT_FG, st["bg"] or DEFAULT_BG
        if st["rev"]:
            fg, bg = bg, fg
        s = f"color:{fg};"
        if bg != DEFAULT_BG:
            s += f"background:{bg};"
        if st["bold"]:
            s += "font-weight:700;"
        return s

    def flush():
        if run:
            out.append(f'<span style="{run_style}">{"".join(run)}</span>')
            run.clear()

    for m in tok.finditer(text):
        if m.group(1) is not None:
            codes = [int(c) if c else 0 for c in m.group(1).split(";")]
            i = 0
            while i < len(codes):
                c = codes[i]
                if c == 0: st.update(fg=None, bg=None, bold=False, rev=False)
                elif c == 1: st["bold"] = True
                elif c == 22: st["bold"] = False
                elif c == 7: st["rev"] = True
                elif c == 27: st["rev"] = False
                elif 30 <= c <= 37: st["fg"] = BASE[c - 30]
                elif 90 <= c <= 97: st["fg"] = BASE[c - 90 + 8]
                elif 40 <= c <= 47: st["bg"] = BASE[c - 40]
                elif 100 <= c <= 107: st["bg"] = BASE[c - 100 + 8]
                elif c == 39: st["fg"] = None
                elif c == 49: st["bg"] = None
                elif c in (38, 48) and i + 2 < len(codes) and codes[i + 1] == 5:
                    st["fg" if c == 38 else "bg"] = xterm(codes[i + 2]); i += 2
                elif c in (38, 48) and i + 4 < len(codes) and codes[i + 1] == 2:
                    st["fg" if c == 38 else "bg"] = "#%02x%02x%02x" % tuple(codes[i + 2:i + 5]); i += 4
                i += 1
            continue
        ch = m.group(2)
        if ch is None:
            continue
        s = style()
        if s != run_style:
            flush(); run_style = s
        if ch == "\n":
            flush(); out.append("\n"); run_style = None
        elif ch in DOTS:
            run.append(f'<i class="w"><i class="dot" style="background:{DOTS[ch]}"></i></i>')
        elif wide(ch):
            run.append(f'<i class="w">{html.escape(ch)}</i>')
        elif ord(ch) > 127 and not 0x2500 <= ord(ch) <= 0x257F:
            # glyphs missing from the mono font fall back to wider ones; pin them to one cell
            run.append(f'<i class="n">{html.escape(ch)}</i>')
        else:
            run.append(html.escape(ch))
    flush()
    return "".join(out)

body = convert(open(sys.argv[1], encoding="utf-8").read().rstrip("\n"))
print(f"""<!doctype html><meta charset="utf-8"><style>
body{{margin:0;display:inline-block;padding:36px;background:linear-gradient(135deg,#2d3142,#1b1d26)}}
.win{{display:inline-block;background:{DEFAULT_BG};border-radius:12px;overflow:hidden;
  box-shadow:0 18px 50px rgba(0,0,0,.45),0 0 0 1px rgba(255,255,255,.06)}}
.bar{{height:30px;background:#22232b;display:flex;align-items:center;gap:8px;padding:0 14px}}
.bar b{{width:12px;height:12px;border-radius:50%;display:block}}
pre{{margin:0;padding:12px 14px 14px;font:15px/18px "DejaVu Sans Mono",monospace;color:{DEFAULT_FG}}}
pre span{{display:inline}}
.w{{font:inherit;font-style:normal;display:inline-block;width:2ch;text-align:center;vertical-align:top}}
.n{{font:inherit;font-style:normal;display:inline-block;width:1ch;text-align:center;vertical-align:top;overflow:visible}}
.dot{{display:inline-block;width:12px;height:12px;border-radius:50%;margin-top:3px}}
</style><div class="win"><div class="bar"><b style="background:#ff5f57"></b><b style="background:#febc2e"></b><b style="background:#28c840"></b></div><pre>{body}</pre></div>""")
