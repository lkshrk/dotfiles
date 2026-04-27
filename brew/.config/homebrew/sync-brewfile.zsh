#!/usr/bin/env zsh
# sync-brewfile — Interactive Brewfile sync based on hostname
# Checks installed packages against all Brewfiles, prompts where to add missing ones

set -euo pipefail

BREWFILE_DIR="${0:h}"
HOSTNAME=$(hostname)

# Hostname -> relevant Brewfiles mapping
typeset -A HOST_BREWFILES=(
  "Topaz.local" "base desktop streaming"
  # Add more hosts: "Host.local" "base desktop ai"
)

get_relevant_brewfiles() {
  local hostname=$1
  # Check explicit mappings first
  if [[ -n ${HOST_BREWFILES[$hostname]} ]]; then
    echo "${HOST_BREWFILES[$hostname]}"
    return
  fi

  # Fallback: always include base, derive others from hostname
  local files="base"
  case $hostname in
    *work*|*desktop*) files="$files desktop" ;;
    *stream*) files="$files streaming" ;;
    *chat*) files="$files chat" ;;
  esac
  echo "$files"
}

echo "📍 Hostname: $HOSTNAME"

# Get all available Brewfiles
all_brewfiles=($(ls "$BREWFILE_DIR"/Brewfile.*(n:t) | sed 's/Brewfile\.//'))

echo "📦 Available Brewfiles: ${all_brewfiles[@]}"
echo

# Get relevant Brewfiles for this host
relevant_brewfiles=($(get_relevant_brewfiles "$HOSTNAME"))
echo "🎯 Relevant Brewfiles for this host: ${relevant_brewfiles[@]}"
echo

# Collect all packages from all Brewfiles
typeset -A brewfile_packages
for bf in "${all_brewfiles[@]}"; do
  local file="$BREWFILE_DIR/Brewfile.$bf"
  [[ -f "$file" ]] || continue

  # Extract packages from this Brewfile
  local formulae=$(grep -E '^brew "' "$file" 2>/dev/null | sed 's/brew "//' | sed 's/"$//' | sed 's/".*//' | sort -u)
  local casks=$(grep -E '^cask "' "$file" 2>/dev/null | sed 's/cask "//' | sed 's/"$//' | sort -u)
  local taps=$(grep -E '^tap "' "$file" 2>/dev/null | sed 's/tap "//' | sed 's/"$//' | sort -u)

  # Store for lookup
  for f in ${(f)formulae}; do brewfile_packages[brew:$f]=1; done
  for c in ${(f)casks}; do brewfile_packages[cask:$c]=1; done
  for t in ${(f)taps}; do brewfile_packages[tap:$t]=1; done
done

# Get installed packages
installed_formulae=$(brew leaves --installed-on-request 2>/dev/null | sort -u)
installed_casks=$(brew list --cask --quiet 2>/dev/null | sort -u)
installed_taps=$(brew tap --quiet 2>/dev/null | sort -u)

# Find missing packages
typeset -a missing_formulae missing_casks missing_taps

for f in ${(f)installed_formulae}; do
  [[ -z ${brewfile_packages[brew:$f]} ]] && missing_formulae+=("$f")
done

for c in ${(f)installed_casks}; do
  [[ -z ${brewfile_packages[cask:$c]} ]] && missing_casks+=("$c")
done

for t in ${(f)installed_taps}; do
  [[ -z ${brewfile_packages[tap:$t]} ]] && missing_taps+=("$t")
done

# Count missing
missing_count=${#missing_formulae}+${#missing_casks}+${#missing_taps}

if [[ $missing_count -eq 0 ]]; then
  echo "✅ All installed packages are tracked in Brewfiles!"
  exit 0
fi

echo "🔍 Found $missing_count package(s) installed but not in any Brewfile"
echo

# Function to prompt for Brewfile selection
prompt_brewfile_choice() {
  local type=$1
  local package=$2

  # Show package info
  case $type in
    brew)
      local info=$(brew info "$package" 2>/dev/null | head -1)
      echo "📌 brew: $package"
      [[ -n $info ]] && echo "   $info"
      ;;
    cask)
      local info=$(brew info --cask "$package" 2>/dev/null | head -1)
      echo "🍺 cask: $package"
      [[ -n $info ]] && echo "   $info"
      ;;
    tap)
      echo "🔧 tap: $package"
      ;;
  esac

  # Show relevant Brewfiles as numbered options
  echo
  echo "Add to which Brewfile?"
  local i=1
  for bf in "${relevant_brewfiles[@]}"; do
    echo "  [$i] $bf (relevant for this host)"
    ((i++))
  done

  # Show other Brewfiles
  for bf in "${all_brewfiles[@]}"; do
    [[ " ${relevant_brewfiles[@]} " =~ " ${bf} " ]] && continue
    echo "  [$i] $bf"
    ((i++))
  done

  echo "  [s] Skip"
  echo "  [q] Quit"
  echo

  local -A choice_map
  i=1
  for bf in "${all_brewfiles[@]}"; do
    choice_map[$i]=$bf
    ((i++))
  done

  local choice
  echo -n "Choice: "
  read -r choice

  case $choice in
    [Qq]*)
      echo "   👋 Quitting"
      exit 0
      ;;
    [Ss]*)
      echo "   ⏭️  Skipped"
      echo
      return
      ;;
    [0-9]*)
      local selected=${choice_map[$choice]}
      if [[ -n $selected ]]; then
        local file="$BREWFILE_DIR/Brewfile.$selected"
        case $type in
          brew) echo "brew \"$package\"" >> "$file" ;;
          cask) echo "cask \"$package\"" >> "$file" ;;
          tap) echo "tap \"$package\"" >> "$file" ;;
        esac
        echo "   ✅ Added to Brewfile.$selected"
        echo
      else
        echo "   ❌ Invalid choice, skipped"
        echo
      fi
      ;;
    *)
      echo "   ⏭️  Skipped"
      echo
      ;;
  esac
}

# Process missing packages
for f in "${missing_formulae[@]}"; do
  prompt_brewfile_choice "brew" "$f"
done

for c in "${missing_casks[@]}"; do
  prompt_brewfile_choice "cask" "$c"
done

for t in "${missing_taps[@]}"; do
  prompt_brewfile_choice "tap" "$t"
done

echo "✨ Done! Review changes with: git diff $BREWFILE_DIR"
