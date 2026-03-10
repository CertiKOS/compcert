#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEMO_DIR="$ROOT/demo/relooper"
CASES_DIR="$DEMO_DIR/cases"
CASES=(switch irreducible)

CCOMP_BIN="${CCOMP:-}"
if [[ -z "$CCOMP_BIN" ]] && [[ -x "$ROOT/_build/install/default/bin/ccomp" ]]; then
  CCOMP_BIN="$ROOT/_build/install/default/bin/ccomp"
fi
if [[ -z "$CCOMP_BIN" ]] && [[ -x "$ROOT/_build/default/extraction/compcert/Driver.exe" ]]; then
  CCOMP_BIN="$ROOT/_build/default/extraction/compcert/Driver.exe"
fi
if [[ -z "$CCOMP_BIN" ]] && command -v ccomp >/dev/null 2>&1; then
  CCOMP_BIN="$(command -v ccomp)"
fi
if [[ -z "$CCOMP_BIN" ]]; then
  echo "ccomp not found. Set CCOMP or build Driver.exe." >&2
  exit 1
fi

export COMPCERT_CONFIG="${COMPCERT_CONFIG:-$ROOT/compcert.ini}"
export RUSTC_BOOTSTRAP="${RUSTC_BOOTSTRAP:-1}"

common_flags=(
  -S
  -fpacked-structs
  -fstruct-passing
  -funstructured-switch
  -std=c18
  -L"$ROOT/runtime"
  -lm
  -rust-edition 2024
)

darwin_flags=()
if [[ "$(uname -s)" == "Darwin" ]]; then
  darwin_flags=(
    -Xpreprocessor -arch
    -Xpreprocessor arm64
    -Xpreprocessor -U__clang__
    -Xpreprocessor -U__BLOCKS__
    -Xpreprocessor '-D__attribute__(x)='
    -Xpreprocessor '-D__asm(x)='
    -Xpreprocessor '-D_Nullable='
    -Xpreprocessor '-D_Nonnull='
    -Xpreprocessor '-D__DARWIN_OS_INLINE=static inline'
    -Xpreprocessor '-Wno-#warnings'
    -Xpreprocessor '-D__uint128_t=unsigned long long'
  )
fi

mkdir -p "$CASES_DIR"
rm -rf "$DEMO_DIR/.cargo-target"

run_case() {
  local case_name="$1"
  local case_dir="$CASES_DIR/$case_name"
  local src_file="$ROOT/c2rust_testbed/working_tests/$case_name.c"
  local test_file="$ROOT/c2rust_testbed/working_tests/test_${case_name}.rs"
  local frontend_status="PASS"
  local rust_status="PASS"
  local test_status="SKIP"
  local dispatcher_status="UNKNOWN"

  rm -rf "$case_dir"
  mkdir -p "$case_dir"

  cp "$src_file" "$case_dir/$case_name.c"

  if ! (
    cd "$case_dir"
    rm -f "$case_name.light.c" "$case_name.s"
    "$CCOMP_BIN" "${common_flags[@]}" "${darwin_flags[@]}" -dclight "$case_name.c" >frontend.log 2>&1
  ); then
    frontend_status="FAIL"
  fi

  if ! (
    cd "$case_dir"
    rm -rf rust_project
    "$CCOMP_BIN" "${common_flags[@]}" "${darwin_flags[@]}" -drustlight "$case_name.c" >rust.log 2>&1
  ); then
    rust_status="FAIL"
  fi

  if [[ "$rust_status" == "PASS" ]]; then
    mkdir -p "$case_dir/rust_project/tests"
    cp "$test_file" "$case_dir/rust_project/tests/"
    if grep -q 'tmp_id_' "$case_dir/rust_project/src/$case_name.rs"; then
      dispatcher_status="PRESENT"
    else
      dispatcher_status="ABSENT"
    fi
    if (
      cd "$case_dir"
      CARGO_TARGET_DIR="$DEMO_DIR/.cargo-target/$case_name" \
        cargo test --manifest-path rust_project/Cargo.toml --test "test_${case_name}" >test.log 2>&1
    ); then
      test_status="PASS"
    else
      test_status="FAIL"
    fi
  else
    : >"$case_dir/test.log"
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$case_name" "$frontend_status" "$rust_status" "$test_status" "$dispatcher_status"
}

{
  printf 'case\tfrontend\trust\ttest\tdispatcher\n'
  for case_name in "${CASES[@]}"; do
    run_case "$case_name"
  done
} >"$DEMO_DIR/summary.tsv"

python3 - "$DEMO_DIR" <<'PY'
from __future__ import annotations

from html import escape
from pathlib import Path
import csv
import sys

demo_dir = Path(sys.argv[1])
summary_path = demo_dir / "summary.tsv"

rows = []
with summary_path.open() as f:
    reader = csv.DictReader(f, delimiter="\t")
    rows = list(reader)

def cls(status: str) -> str:
    return {
        "PASS": "pass",
        "FAIL": "fail",
        "SKIP": "skip",
        "ABSENT": "pass",
        "PRESENT": "fail",
        "UNKNOWN": "skip",
    }.get(status, "skip")

def read_text(path: Path) -> str:
    if not path.exists():
      return f"[missing] {path.name}"
    return path.read_text()

def code_panel(title: str, language: str, body: str) -> str:
    return (
        '<article class="panel">'
        f"<h3>{escape(title)}</h3>"
        f'<pre><code class="language-{language}">{escape(body)}</code></pre>'
        "</article>"
    )

case_sections = []
table_rows = []
for row in rows:
    case_name = row["case"]
    case_dir = demo_dir / "cases" / case_name
    src_name = f"{case_name}.c"
    light_name = f"{case_name}.light.c"
    rs_name = f"{case_name}.rs"
    test_name = f"test_{case_name}.rs"

    table_rows.append(
        "<tr>"
        f"<td>{escape(case_name)}</td>"
        f'<td class="{cls(row["frontend"])}">{escape(row["frontend"])}</td>'
        f'<td class="{cls(row["rust"])}">{escape(row["rust"])}</td>'
        f'<td class="{cls(row["test"])}">{escape(row["test"])}</td>'
        f'<td class="{cls(row["dispatcher"])}">{escape(row["dispatcher"])}</td>'
        "</tr>"
    )

    panels = [
        code_panel("1. Source C", "c", read_text(case_dir / src_name)),
        code_panel("2. Clight Output (.light.c)", "c", read_text(case_dir / light_name)),
        code_panel("3. Rust Output (.rs)", "rust", read_text(case_dir / "rust_project" / "src" / rs_name)),
        code_panel("4. Rust Test", "rust", read_text(case_dir / "rust_project" / "tests" / test_name)),
        code_panel("5. Frontend Log", "text", read_text(case_dir / "frontend.log")),
        code_panel("6. Rust Translation Log", "text", read_text(case_dir / "rust.log")),
        code_panel("7. Rust Test Log", "text", read_text(case_dir / "test.log")),
    ]

    case_sections.append(
        '<section class="case">'
        '<div class="case-header">'
        f"<h2>Case: {escape(case_name)}</h2>"
        f"<div>Frontend: <span class=\"{cls(row['frontend'])}\">{escape(row['frontend'])}</span> | "
        f"Rust: <span class=\"{cls(row['rust'])}\">{escape(row['rust'])}</span> | "
        f"Rust test: <span class=\"{cls(row['test'])}\">{escape(row['test'])}</span> | "
        f"Dispatcher variable: <span class=\"{cls(row['dispatcher'])}\">{escape(row['dispatcher'])}</span></div>"
        "</div>"
        '<div class="grid">'
        + "".join(panels)
        + "</div></section>"
    )

html = f"""<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Structured Rust CFG Demo</title>
    <link
      rel="stylesheet"
      href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism.min.css"
    />
    <style>
      :root {{
        --bg: #f4f0e8;
        --fg: #1e1e1e;
        --panel: #fffefb;
        --border: #d8cdb8;
        --accent: #1f3b4d;
        --accent-soft: #efe4d1;
      }}
      body {{ font-family: sans-serif; margin: 0; background: var(--bg); color: var(--fg); }}
      header {{ padding: 1rem 1.5rem; background: var(--accent); color: #fff; }}
      h1, h2, h3 {{ margin: 0.2rem 0; }}
      main {{ padding: 1rem 1.5rem 2rem; }}
      .summary {{ width: 100%; border-collapse: collapse; margin: 1rem 0 1.5rem; background: #fff; }}
      .summary th, .summary td {{ border: 1px solid #ddd; padding: 0.45rem 0.55rem; text-align: left; }}
      .pass {{ color: #0a6f2f; font-weight: 700; }}
      .fail {{ color: #a31515; font-weight: 700; }}
      .skip {{ color: #7a6a00; font-weight: 700; }}
      .case {{ margin: 1.2rem 0 2rem; border: 1px solid var(--border); background: var(--panel); }}
      .case-header {{ padding: 0.7rem 0.8rem; background: var(--accent-soft); border-bottom: 1px solid var(--border); }}
      .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(380px, 1fr)); gap: 0.8rem; padding: 0.8rem; }}
      .panel {{ border: 1px solid #ddd; background: #fff; }}
      .panel h3 {{ font-size: 0.95rem; padding: 0.45rem 0.55rem; background: #f7f7f7; border-bottom: 1px solid #ddd; }}
      pre {{ margin: 0; max-height: 360px; overflow: auto; }}
      pre code {{ display: block; padding: 0.65rem; white-space: pre; }}
      .note {{ max-width: 70rem; line-height: 1.45; }}
    </style>
  </head>
  <body>
    <header>
      <h1>Structured Rust CFG Demo</h1>
      <div>Generated by <code>demo/relooper/relooper_demo.sh</code></div>
    </header>
    <main>
      <h2>Strategy</h2>
      <p class="note">
        This demo runs each case twice with the current <code>bl/rust-cns</code> compiler: once for
        Clight output and once for Rust output. The generated Rust is then tested with Cargo. The
        main thing to inspect is the dispatcher column: for the structured path we want the synthetic
        <code>tmp_id_*</code> state variable to be absent.
      </p>
      <table class="summary">
        <thead>
          <tr><th>Case</th><th>Frontend</th><th>Rust Translation</th><th>Rust Test</th><th>Dispatcher</th></tr>
        </thead>
        <tbody>
          {"".join(table_rows)}
        </tbody>
      </table>
      {"".join(case_sections)}
    </main>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-rust.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-c.min.js"></script>
  </body>
</html>
"""

(demo_dir / "index.html").write_text(html)
PY

rm -rf "$DEMO_DIR/.cargo-target"

echo "Demo updated in $DEMO_DIR"
