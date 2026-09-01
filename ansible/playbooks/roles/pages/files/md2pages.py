#!/usr/bin/env python3
"""Render .md / .md.j2 files into static HTML pages. (Python 3.9+)"""
import argparse
import re
from pathlib import Path

import jinja2
import markdown

TEMPLATE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
body {{ font-family: system-ui, sans-serif; max-width: 46rem; margin: 2rem auto;
        padding: 0 1rem; line-height: 1.6; color: #222; }}
nav {{ border-bottom: 1px solid #ddd; margin-bottom: 1.5rem; padding-bottom: .5rem;
       font-size: .9rem; }}
nav a {{ margin-right: .75rem; text-decoration: none; color: #0645ad; }}
code {{ background: #f4f4f4; padding: .1em .3em; border-radius: 3px; }}
pre {{ background: #f4f4f4; padding: .75rem; overflow-x: auto; border-radius: 4px; }}
pre code {{ background: none; padding: 0; }}
</style>
</head>
<body>
<nav>{nav}</nav>
{content}
</body>
</html>
"""

def stem_of(path: Path) -> str:
    """index.md -> index; index.md.j2 -> index"""
    return path.name.removesuffix(".j2").removesuffix(".md")

def render(src: Path, out: Path, **context) -> None:
    out.mkdir(parents=True, exist_ok=True)
    files = sorted(set(src.glob("*.md")) | set(src.glob("*.md.j2")))
    stems = [stem_of(p) for p in files]

    # Pass 1: read + Jinja-render all sources
    texts = {}
    for p in files:
        text = p.read_text()
        if p.name.endswith(".j2"):
            text = jinja2.Template(text, undefined=jinja2.StrictUndefined).render(**context)
        texts[stem_of(p)] = text

    # Nav order: pages in the order they are linked from the index,
    # then any pages the index doesn't list, alphabetically.
    order = []
    if "index" in texts:
        order.append("index")
        for m in re.finditer(r'\]\(([^)\s#]+)\.md', texts["index"]):
            target = m.group(1)
            if "://" not in target and target in stems and target not in order:
                order.append(target)
    order += [s for s in sorted(stems) if s not in order]

    nav = "".join(
        f'<a href="{s}.html">{"home" if s == "index" else s}</a>'
        for s in order
    )

    # Pass 2: markdown -> HTML
    for p in files:
        stem = stem_of(p)
        html = markdown.markdown(
            texts[stem], extensions=["fenced_code", "tables", "sane_lists"]
        )
        html = re.sub(r'href="([^"#]+)\.md', r'href="\1.html', html)
        title = "home" if stem == "index" else stem.replace("-", " ")
        (out / f"{stem}.html").write_text(
            TEMPLATE.format(title=title, nav=nav, content=html)
        )
    print(f"Rendered {len(files)} pages -> {out}/")

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--src", default=".")
    parser.add_argument("--out", default="dist")
    parser.add_argument("--base-domain", default="localhost",
                        help="Passed to .md.j2 templates as {{ base_domain }}")
    args = parser.parse_args()
    render(Path(args.src), Path(args.out), base_domain=args.base_domain)

if __name__ == "__main__":
    main()
