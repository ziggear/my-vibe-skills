#!/usr/bin/env bash
# Codex exploration helper for ~/.claude/skills/codex-code-agent
# Subcommands: check | run
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_TEMPLATE="${SKILL_ROOT}/prompts/exploration-handoff.en.md"

codex_home="${CODEX_HOME:-${HOME}/.codex}"

have_codex() {
  command -v codex >/dev/null 2>&1
}

auth_heuristic_ok() {
  if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    return 0
  fi
  if [[ -f "${codex_home}/auth.json" ]]; then
    return 0
  fi
  return 1
}

cmd_check() {
  echo "== Codex code agent: check =="
  if ! have_codex; then
    echo "codex: NOT FOUND on PATH"
    echo "Install: npm i -g @openai/codex"
    return 1
  fi
  echo "codex: OK ($(command -v codex))"
  if codex --version >/dev/null 2>&1; then
    codex --version 2>&1 | head -n 3 || true
  fi
  if auth_heuristic_ok; then
    if [[ -n "${OPENAI_API_KEY:-}" ]]; then
      echo "auth: OPENAI_API_KEY is set (API-key style runs may work)"
    fi
    if [[ -f "${codex_home}/auth.json" ]]; then
      echo "auth: found ${codex_home}/auth.json"
    fi
  else
    echo "auth: no OPENAI_API_KEY and no ${codex_home}/auth.json (credentials may live in OS keyring)"
    echo "If codex exec fails with auth errors, run: codex login"
  fi
  echo "Template: ${DEFAULT_TEMPLATE}"
  return 0
}

usage() {
  cat <<'EOF'
Usage:
  codex-explore.sh check

  codex-explore.sh run -C <workspace> -p <prompt-file> [options]
  codex-explore.sh run -C <workspace> --title ... --detail ... [options]

Options:
  -C, --cd DIR          Workspace for Codex (default: pwd)
  -p, --prompt-file F   Final prompt file (already filled; mutually exclusive with --title/--detail)
  -t, --template F      Template path when using --title/--detail (default: bundled exploration-handoff.en.md)
  --title TEXT          Build prompt from template (requires --detail)
  --detail TEXT         Build prompt from template (requires --title)
  --scope TEXT          Substitute @SCOPE_HINT@ (default: unknown; infer from repo)
  --atlassian-file F    Substitute @ATLASSIAN_CONTEXT@ from file (multiline-safe); omit for literal "none"
  -o, --output-last F   Pass through to codex exec -o (final message file)
  --full-auto           codex exec --full-auto (workspace-write + on-request); default is read-only sandbox

Environment:
  CODEX_HOME            Override ~/.codex location for auth.json heuristic

Examples:
  bash codex-explore.sh check

  bash codex-explore.sh run -C "$(pwd)" -p /tmp/prompt.md

  bash codex-explore.sh run -C "$(pwd)" \
    --title "Invoice rounding" \
    --detail "Cents off by one for tax-inclusive lines; repro on AU tenant sample" \
    --atlassian-file /tmp/jira-snippet.txt
EOF
}

render_template_python() {
  local tpl_path="$1" out_path="$2" title="$3" detail="$4" scope="$5" atlassian_path="$6"
  python3 - "$tpl_path" "$out_path" "$title" "$detail" "$scope" "$atlassian_path" <<'PY'
import pathlib
import sys

tpl_path, out_path, title, detail, scope, atlassian_path = sys.argv[1:7]
text = pathlib.Path(tpl_path).read_text(encoding="utf-8")
if atlassian_path:
    atl_body = pathlib.Path(atlassian_path).read_text(encoding="utf-8")
else:
    atl_body = "none"
text = text.replace("@TASK_TITLE@", title)
text = text.replace("@TASK_DETAIL@", detail)
text = text.replace("@SCOPE_HINT@", scope)
text = text.replace("@ATLASSIAN_CONTEXT@", atl_body)
pathlib.Path(out_path).write_text(text, encoding="utf-8")
PY
}

cmd_run() {
  local workdir="" prompt_file="" user_prompt_file="" template_file="" out_last=""
  local title="" detail="" scope="unknown; infer from repository layout and docs."
  local atlassian_file="" use_full_auto="0"
  local tmp_prompt="" created_tmp="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -C|--cd)
        workdir="$2"
        shift 2
        ;;
      -p|--prompt-file)
        user_prompt_file="$2"
        prompt_file="$2"
        shift 2
        ;;
      -t|--template)
        template_file="$2"
        shift 2
        ;;
      --title)
        title="$2"
        shift 2
        ;;
      --detail)
        detail="$2"
        shift 2
        ;;
      --scope)
        scope="$2"
        shift 2
        ;;
      --atlassian-file)
        atlassian_file="$2"
        shift 2
        ;;
      -o|--output-last)
        out_last="$2"
        shift 2
        ;;
      --full-auto)
        use_full_auto="1"
        shift 1
        ;;
      -h|--help)
        usage
        return 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage >&2
        return 2
        ;;
    esac
  done

  if [[ -z "${workdir}" ]]; then
    workdir="$(pwd)"
  fi
  if [[ ! -d "${workdir}" ]]; then
    echo "Workspace is not a directory: ${workdir}" >&2
    return 1
  fi

  local want_template="0"
  if [[ -n "${title}" || -n "${detail}" || -n "${template_file}" || -n "${atlassian_file}" ]]; then
    want_template="1"
  fi

  if [[ "${want_template}" == "1" ]]; then
    if [[ -n "${user_prompt_file}" ]]; then
      echo "Do not combine -p/--prompt-file with --title/--detail/--template/--atlassian-file." >&2
      return 2
    fi
    if [[ -z "${title}" || -z "${detail}" ]]; then
      echo "Template mode requires both --title and --detail." >&2
      return 2
    fi
    if [[ -z "${template_file}" ]]; then
      template_file="${DEFAULT_TEMPLATE}"
    fi
    if [[ ! -f "${template_file}" ]]; then
      echo "Template not found: ${template_file}" >&2
      return 1
    fi
    if [[ -n "${atlassian_file}" && ! -f "${atlassian_file}" ]]; then
      echo "Atlassian context file not found: ${atlassian_file}" >&2
      return 1
    fi
    tmp_prompt="$(mktemp -t codex-explore-prompt.XXXXXX)"
    created_tmp="1"
    render_template_python "${template_file}" "${tmp_prompt}" "${title}" "${detail}" "${scope}" "${atlassian_file}"
    prompt_file="${tmp_prompt}"
  fi

  if [[ -z "${prompt_file}" || ! -f "${prompt_file}" ]]; then
    echo "Prompt file missing. Use -p/--prompt-file, or --title and --detail (optional -t / --atlassian-file)." >&2
    usage >&2
    return 2
  fi

  if ! have_codex; then
    echo "codex not found. Install: npm i -g @openai/codex" >&2
    return 1
  fi

  if ! auth_heuristic_ok; then
    echo "Warning: no OPENAI_API_KEY and no ${codex_home}/auth.json; if exec fails, run: codex login" >&2
  fi

  echo "== Codex exec (workspace: ${workdir}) =="

  local -a base
  base=(exec -C "${workdir}" --sandbox read-only --ask-for-approval never --color auto)

  if [[ "${use_full_auto}" == "1" ]]; then
    base=(exec -C "${workdir}" --full-auto --color auto)
  fi

  if [[ -n "${out_last}" ]]; then
    base+=(-o "${out_last}")
  fi

  cleanup_tmp() {
    if [[ "${created_tmp}" == "1" && -n "${tmp_prompt}" ]]; then
      rm -f "${tmp_prompt}"
    fi
  }
  trap cleanup_tmp EXIT

  cat "${prompt_file}" | codex "${base[@]}" -
}

main() {
  local sub="${1:-}"
  shift || true
  case "${sub}" in
    check)
      cmd_check "$@"
      ;;
    run)
      cmd_run "$@"
      ;;
    ""|-h|--help)
      usage
      ;;
    *)
      echo "Unknown subcommand: ${sub}" >&2
      usage >&2
      return 2
      ;;
  esac
}

main "$@"
