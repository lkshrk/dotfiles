# --- tail-claude: stream Claude Code Task-tool subagent transcripts ---------
#
# Usage:
#   tail-claude              # tail latest task in current project (cwd → slug)
#   tail-claude -l           # list 20 recent tasks in current project
#   tail-claude -L           # list 30 recent tasks across ALL projects
#   tail-claude -a           # tail latest task across ALL projects
#   tail-claude -f           # follow: auto-switch to newest task as it appears
#   tail-claude <file>       # tail a specific .output file
#   tail-claude -h           # help
#
# Env:
#   CLAUDE_TMP_ROOT  (default: /private/tmp/claude-<uid>)

_tail_claude_root() {
  print -r -- "${CLAUDE_TMP_ROOT:-/private/tmp/claude-$(id -u)}"
}

# /Users/foo/Dev/KAM → -Users-foo-Dev-KAM
_tail_claude_slug() {
  local p="${1:-$PWD}"
  print -r -- "${p//\//-}"
}

_tail_claude_project_dir() {
  local d="$(_tail_claude_root)/$(_tail_claude_slug)"
  [[ -d "$d" ]] || return 1
  print -r -- "$d"
}

# Args: <root-dir> <limit>; emits newest N *.output paths.
# Excludes hook_*.output (PreToolUse/PostToolUse hook outputs — high churn,
# not subagent transcripts).
_tail_claude_list() {
  local root="$1" lim="${2:-10}"
  local -a files
  files=("$root"/**/*.output(N.om))
  files=(${files:#*/hook_*.output})
  print -rl -- "${files[@]:0:$lim}"
}

_tail_claude_latest() {
  _tail_claude_list "$1" 1
}

# jq filter: decode JSONL transcript to human-readable colored chunks
_tail_claude_jq_filter() {
  cat <<'JQ'
  . as $line
  | .message as $m
  | if $m.role == "user" then
      ($m.content[]? | .content // .text // empty)
    elif $m.role == "assistant" then
      ($m.content[]? |
        if .type == "text" then
          "\n\u001b[36m[assistant]\u001b[0m " + .text
        elif .type == "tool_use" then
          "\n\u001b[33m[tool:" + .name + "]\u001b[0m " +
          (.input | tostring | if length > 400 then .[0:400] + "…" else . end)
        elif .type == "tool_result" then
          "\n\u001b[32m[tool_result]\u001b[0m " +
          ((.content // "") |
            if type == "array" then (.[0].text // "") else . end
            | tostring
            | if length > 400 then .[0:400] + "…" else . end)
        else empty end)
    else empty end
JQ
}

_tail_claude_pretty_tail() {
  local f="$1"
  print -u2 -P "%F{magenta}>> $f%f"
  tail -n 200 -F "$f" 2>/dev/null |
    jq -rR --unbuffered "fromjson? // empty | $(_tail_claude_jq_filter)" 2>/dev/null
}

_tail_claude_follow() {
  local root current new tail_pid
  root="$(_tail_claude_project_dir)" || { print -u2 "No Claude tasks for $PWD"; return 1 }
  current="$(_tail_claude_latest "$root")"
  [[ -n "$current" ]] || { print -u2 "No .output files under $root"; return 1 }

  _tail_claude_pretty_tail "$current" &
  tail_pid=$!

  trap 'kill $tail_pid 2>/dev/null; return 0' INT TERM

  # Debounce: only switch when a different file has been the newest for 2
  # consecutive polls (3s apart). Prevents churn from concurrent task writes.
  local candidate="" candidate_seen=0
  while sleep 3; do
    new="$(_tail_claude_latest "$root")"
    [[ -z "$new" || "$new" == "$current" ]] && { candidate=""; candidate_seen=0; continue }
    if [[ "$new" == "$candidate" ]]; then
      (( candidate_seen++ ))
      if (( candidate_seen >= 1 )); then
        kill "$tail_pid" 2>/dev/null
        current="$new"; candidate=""; candidate_seen=0
        _tail_claude_pretty_tail "$current" &
        tail_pid=$!
      fi
    else
      candidate="$new"; candidate_seen=0
    fi
  done
}

tail-claude() {
  (( $+commands[jq] )) || { print -u2 "tail-claude: jq not installed"; return 1 }

  local root f
  case "${1:-}" in
    -h|--help)
      print -- "Usage: tail-claude [-l|-L|-a|-f|<file>|-h]"
      print -- "  (no arg)  tail newest task in current project"
      print -- "  -l        list 20 recent tasks in current project"
      print -- "  -L        list 30 recent tasks across ALL projects"
      print -- "  -a        tail newest task across ALL projects"
      print -- "  -f        follow: auto-switch when new task starts"
      print -- "  <file>    tail specific .output file"
      return 0
      ;;
    -l)
      root="$(_tail_claude_project_dir)" || { print -u2 "No Claude tasks for $PWD"; return 1 }
      _tail_claude_list "$root" 20
      ;;
    -L)
      _tail_claude_list "$(_tail_claude_root)" 30
      ;;
    -a)
      f="$(_tail_claude_list "$(_tail_claude_root)" 1)"
      [[ -n "$f" ]] || { print -u2 "No .output files under $(_tail_claude_root)"; return 1 }
      _tail_claude_pretty_tail "$f"
      ;;
    -f)
      _tail_claude_follow
      ;;
    '')
      root="$(_tail_claude_project_dir)" || { print -u2 "No Claude tasks for $PWD"; return 1 }
      f="$(_tail_claude_latest "$root")"
      [[ -n "$f" ]] || { print -u2 "No .output files under $root"; return 1 }
      _tail_claude_pretty_tail "$f"
      ;;
    *)
      [[ -f "$1" ]] || { print -u2 "File not found: $1"; return 1 }
      _tail_claude_pretty_tail "$1"
      ;;
  esac
}
