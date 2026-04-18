#!/bin/sh
input=$(cat)

# --- folder (basename of cwd) ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
folder=$(basename "$cwd")

# --- git branch (skip optional locks) ---
branch=""
if [ -n "$cwd" ] && [ -d "$cwd/.git" ] || git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
fi

# --- model display name ---
model=$(echo "$input" | jq -r '.model.display_name // ""')

# --- context bar ---
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Build context bar (10 blocks): filled = used portion, open = remaining
ctx_bar=""
if [ -n "$used" ]; then
  # Use awk for all float arithmetic to avoid bc dependency and rounding surprises.
  # filled is clamped to [0,10] so empty is always non-negative.
  read -r filled used_int <<EOF
$(awk "BEGIN{
  u = $used + 0
  f = int(u / 10 + 0.5)
  if (f > 10) f = 10
  if (f < 0)  f = 0
  e = 10 - f
  printf \"%d %d\n\", f, int(u + 0.5)
}")
EOF
  empty=$((10 - filled))
  bar=""
  i=0
  while [ "$i" -lt "$filled" ]; do
    bar="${bar}█"
    i=$((i + 1))
  done
  i=0
  while [ "$i" -lt "$empty" ]; do
    bar="${bar}░"
    i=$((i + 1))
  done
  ctx_bar="[${bar}] ${used_int}%"
fi

# --- assemble ---
# folder  branch  model  ctx_bar
parts=""

if [ -n "$folder" ]; then
  parts="$folder"
fi

if [ -n "$branch" ]; then
  parts="${parts}  ${branch}"
fi

if [ -n "$model" ]; then
  parts="${parts}  ${model}"
fi

if [ -n "$ctx_bar" ]; then
  parts="${parts}  ${ctx_bar}"
fi

printf '%s' "$parts"
