"""Write $NAME.plg from plugin.plg.tmpl, and keep the change history of the old .plg.

Usage: render.py TEMPLATE

Reads NAME, TITLE, VERSION, PLUGIN_VERSION and PACKAGE from the environment, and the
sha256 from build/$PACKAGE.txz.sha256.
"""

import os
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from xml.sax.saxutils import escape


def main() -> None:
    template = Path(sys.argv[1]).read_text()
    env = {k: os.environ[k] for k in ("NAME", "TITLE", "VERSION", "PLUGIN_VERSION", "PACKAGE")}
    sha256 = Path(f"build/{env['PACKAGE']}.txz.sha256").read_text().split()[0]
    plg = Path(f"{env['NAME']}.plg")

    history = ""
    if plg.exists():
        match = re.search(r"<CHANGES>\s*(.*?)\s*</CHANGES>", plg.read_text(), re.S)
        if match:
            history = match.group(1)
    entry = f"### {env['PLUGIN_VERSION']}\n- {env['TITLE']} {env['VERSION']}"
    changes = entry + ("\n\n" + history if history else "")

    values = {**env, "SHA256": sha256}
    text = template
    for key, value in values.items():
        text = text.replace(f"@{key}@", escape(value))
    text = text.replace("@CHANGES@", changes)
    if re.search(r"@[A-Z0-9_]+@", text):
        sys.exit("error: the template has a placeholder with no value")

    root = ET.fromstring(text)
    url = root.find("FILE/URL").text
    expected = (
        f"https://github.com/dtomlinson91/{env['NAME']}/releases/download/"
        f"{env['PLUGIN_VERSION']}/{env['PACKAGE']}.txz"
    )
    if root.get("version") != env["PLUGIN_VERSION"] or url != expected:
        sys.exit(f"error: the rendered .plg has version {root.get('version')} and URL {url}")

    plg.write_text(text)
    print(f"wrote {plg}: version {env['PLUGIN_VERSION']}, {env['TITLE']} {env['VERSION']}")


if __name__ == "__main__":
    main()
