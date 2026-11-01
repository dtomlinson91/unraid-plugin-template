"""Write $NAME.plg from plugin-slackware.plg.tmpl, and keep the change history of the old .plg.

Usage: render.py TEMPLATE

Reads NAME, TITLE, VERSION, SOURCES and PLUGIN_VERSION from the environment, the bases from
build/bases.tsv, and the sha256 of each package from build/<package>.txz.sha256.
"""

import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import escape

FIELDS = ("glob", "tree", "glibc", "image", "path", "md5", "version", "package")


def main() -> None:
    template = Path(sys.argv[1]).read_text()
    env = {k: os.environ[k] for k in ("NAME", "TITLE", "VERSION", "SOURCES", "PLUGIN_VERSION")}
    bases = [
        dict(zip(FIELDS, line.split("\t")))
        for line in Path("build/bases.tsv").read_text().splitlines()
        if line.strip()
    ]
    if not bases:
        sys.exit("error: build/bases.tsv has no bases")
    for base in bases:
        sha_file = Path(f"build/{base['package']}.txz.sha256")
        base["sha256"] = sha_file.read_text().split()[0]
    plg = Path(f"{env['NAME']}.plg")

    history = ""
    if plg.exists():
        match = re.search(r"<CHANGES>\s*(.*?)\s*</CHANGES>", plg.read_text(), re.S)
        if match:
            history = match.group(1)
    lines = [f"- {env['TITLE']} {b['version']} for Unraid {b['glob']} (Slackware {b['tree']})" for b in bases]
    entry = f"### {env['PLUGIN_VERSION']}\n" + "\n".join(lines)
    changes = entry + ("\n\n" + history if history else "")

    files = "".join(
        f'<FILE Name="&plugin;/{b["package"]}.txz">\n'
        f"<URL>&releaseURL;/{b['package']}.txz</URL>\n"
        f"<SHA256>{b['sha256']}</SHA256>\n"
        f"</FILE>\n\n"
        for b in bases
    )
    guard = "\n".join(f"  {b['glob']}) ;;" for b in bases)
    select = "\n".join(f"  {b['glob']}) package={b['package']} ;;" for b in bases)
    checks = "\n".join(f"check {b['package']}.txz {b['sha256']}" for b in bases)
    keep = " ".join(f'! -name "{b["package"]}.txz"' for b in bases)
    supported = ", ".join(b["glob"] for b in bases)
    minimum = min(
        (b["glob"].replace("*", "0") for b in bases),
        key=lambda v: [int(p) for p in v.split(".") if p.isdigit()],
    )

    values = {**env, "MIN": minimum, "SUPPORTED": supported}
    text = template
    for key, value in values.items():
        text = text.replace(f"@{key}@", escape(value))
    blocks = {"CHANGES": changes, "FILES": files, "GUARD": guard, "SELECT": select, "CHECKS": checks, "KEEP": keep}
    for key, value in blocks.items():
        text = text.replace(f"@{key}@", value)
    if re.search(r"@[A-Z0-9_]+@", text):
        sys.exit("error: the template has a placeholder with no value")

    root = ET.fromstring(text)
    urls = [f.find("URL").text for f in root.findall("FILE") if f.find("URL") is not None]
    expected = [
        f"https://github.com/dtomlinson91/{env['NAME']}/releases/download/{env['PLUGIN_VERSION']}/{b['package']}.txz"
        for b in bases
    ]
    if root.get("version") != env["PLUGIN_VERSION"] or urls != expected:
        sys.exit(f"error: the rendered .plg has version {root.get('version')} and URLs {urls}")

    plg.write_text(text)
    print(f"wrote {plg}: version {env['PLUGIN_VERSION']}, {env['TITLE']} {env['VERSION']}")


if __name__ == "__main__":
    main()
