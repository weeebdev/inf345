#!/usr/bin/env bash
# Builds every Slidev lecture deck under lectures/*/slides.md into dist/<slug>/,
# copies exported PDFs from pdfs/ (if present) into dist/pdfs/, and generates a
# dist/index.html landing page linking to every deck (newest lecture first).
#
# Lecture directories are discovered dynamically -- adding a new
# lectures/NN-slug/slides.md requires no changes here or in the workflow.
#
# Usage: scripts/build-pages.sh
# Env vars:
#   OUT_DIR      output directory (default: dist)
#   BASE_PREFIX  Pages base path prefix, no trailing slash (default: /inf345)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="${OUT_DIR:-dist}"
BASE_PREFIX="${BASE_PREFIX:-/inf345}"
SITE_TITLE="INF345 — Fundamentals of DevOps · Lectures"

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

shopt -s nullglob
slide_files=(lectures/*/slides.md)
shopt -u nullglob

if [ "${#slide_files[@]}" -eq 0 ]; then
  echo "::error::No lecture decks found under lectures/*/slides.md" >&2
  exit 1
fi

slugs=()
for f in "${slide_files[@]}"; do
  slugs+=("$(basename "$(dirname "$f")")")
done

# Newest lecture first (lecture dirs are zero-padded NN-slug, so a reverse
# lexical sort is a reverse numeric sort too).
IFS=$'\n' sorted_slugs=($(printf '%s\n' "${slugs[@]}" | sort -r))
unset IFS

echo "Discovered ${#sorted_slugs[@]} lecture deck(s): ${sorted_slugs[*]}"

for slug in "${sorted_slugs[@]}"; do
  src="lectures/$slug/slides.md"
  # --out MUST be absolute: slidev resolves a relative --out against the
  # entry file's own directory, not the cwd, so "dist/$slug" silently lands
  # in lectures/$slug/dist/$slug and the published site 404s.
  out="$REPO_ROOT/$OUT_DIR/$slug"
  base="$BASE_PREFIX/$slug/"
  echo "::group::Building $slug -> $out"
  npx slidev build "$src" --out "$out" --base "$base"
  if [ ! -f "$out/index.html" ]; then
    echo "::error::$slug built but $out/index.html is missing" >&2
    exit 1
  fi
  echo "::endgroup::"
done

if [ -d "pdfs" ]; then
  mkdir -p "$OUT_DIR/pdfs"
  shopt -s nullglob
  pdf_files=(pdfs/*.pdf)
  shopt -u nullglob
  if [ "${#pdf_files[@]}" -gt 0 ]; then
    cp -v "${pdf_files[@]}" "$OUT_DIR/pdfs/"
  fi
fi

deck_title() {
  local src="$1" slug="$2" title
  title="$(grep -m1 '^title:' "$src" 2>/dev/null | sed -E 's/^title:[[:space:]]*"?//; s/"?[[:space:]]*$//')"
  if [ -z "$title" ]; then
    title="$slug"
  fi
  printf '%s' "$title"
}

html_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  printf '%s' "$s"
}

index_file="$OUT_DIR/index.html"
{
  cat <<HTML_HEAD
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${SITE_TITLE}</title>
<style>
  :root { color-scheme: light dark; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    max-width: 720px;
    margin: 0 auto;
    padding: 2rem 1.25rem 4rem;
    line-height: 1.5;
    color: #1f2328;
    background: #fff;
  }
  h1 { font-size: 1.4rem; margin-bottom: 0.25rem; }
  p.sub { color: #57606a; margin-top: 0; }
  ul { list-style: none; padding: 0; margin: 1.5rem 0 0; }
  li {
    border: 1px solid #d0d7de;
    border-radius: 8px;
    padding: 0.9rem 1rem;
    margin-bottom: 0.75rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem;
    flex-wrap: wrap;
  }
  li .title { font-weight: 600; }
  li a { color: #0969da; text-decoration: none; }
  li a:hover { text-decoration: underline; }
  .links { display: flex; gap: 0.75rem; white-space: nowrap; }
  footer { margin-top: 2.5rem; color: #8c959f; font-size: 0.85rem; }
  @media (prefers-color-scheme: dark) {
    body { background: #0d1117; color: #c9d1d9; }
    p.sub, footer { color: #8b949e; }
    li { border-color: #30363d; }
    li a { color: #58a6ff; }
  }
</style>
</head>
<body>
<h1>${SITE_TITLE}</h1>
<p class="sub">Slidev decks, built and published automatically from the course repository.</p>
<ul>
HTML_HEAD

  for slug in "${sorted_slugs[@]}"; do
    src="lectures/$slug/slides.md"
    title="$(html_escape "$(deck_title "$src" "$slug")")"
    pdf_link=""
    if [ -f "pdfs/$slug.pdf" ]; then
      pdf_link="<a href=\"pdfs/${slug}.pdf\">PDF</a>"
    fi
    printf '  <li><span class="title">%s</span><span class="links"><a href="%s/">Slides</a>%s</span></li>\n' \
      "$title" "$slug" "${pdf_link:+ $pdf_link}"
  done

  cat <<'HTML_TAIL'
</ul>
<footer>Built automatically by GitHub Actions from lectures/**/slides.md.</footer>
</body>
</html>
HTML_TAIL
} > "$index_file"

echo "Wrote $index_file"
