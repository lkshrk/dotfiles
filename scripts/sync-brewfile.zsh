#!/usr/bin/env zsh
# sync-brewfile — Interactive bidirectional Brewfile sync
# 1. Installed but not in Brewfile → add to Brewfile
# 2. In Brewfile but not installed → install OR remove from Brewfile

set -euo pipefail

DOTFILES_DIR="$(dirname "$(dirname "$0")")"
BREWFILE_DIR="$DOTFILES_DIR/brew/.config/homebrew"
HOSTNAME=$(hostname)

# Source host config to get BREW_MODULES
load_brew_modules() {
  local hostfile="$DOTFILES_DIR/hosts/$(hostname -s).conf"
  if [[ -f "$hostfile" ]]; then
    source "$hostfile"
  else
    # Fallback to default (empty modules = base only)
    BREW_MODULES=()
  fi
}

get_relevant_brewfiles() {
  load_brew_modules

  # Always include base
  local files="base"

  # Add modules from host config
  for mod in "${BREW_MODULES[@]}"; do
    files="$files $mod"
  done

  echo "$files"
}

echo "📍 Hostname: $HOSTNAME"

# Get all available Brewfiles
all_brewfiles=($(cd "$BREWFILE_DIR" && ls Brewfile.* 2>/dev/null | sed 's/Brewfile\.//'))

echo "📦 Available Brewfiles: ${all_brewfiles[@]}"
echo

# Get relevant Brewfiles for this host
relevant_brewfiles=($(get_relevant_brewfiles "$HOSTNAME"))
echo "🎯 Relevant Brewfiles for this host: ${relevant_brewfiles[@]}"
echo

# Collect all packages from all Brewfiles
typeset -A brewfile_packages brewfile_package_source
for bf in "${all_brewfiles[@]}"; do
  local file="$BREWFILE_DIR/Brewfile.$bf"
  [[ -f "$file" ]] || continue

  # Extract packages from this Brewfile
  local formulae=$(grep -E '^brew "' "$file" 2>/dev/null | sed 's/brew "//' | sed 's/"$//' | sed 's/".*//' | sort -u)
  local casks=$(grep -E '^cask "' "$file" 2>/dev/null | sed 's/cask "//' | sed 's/"$//' | sort -u)
  local taps=$(grep -E '^tap "' "$file" 2>/dev/null | sed 's/tap "//' | sed 's/"$//' | sort -u)

  # Store for lookup and track which file they came from
  for f in ${(f)formulae}; do
    brewfile_packages[brew:$f]=1
    brewfile_package_source[brew:$f]="$bf"
  done
  for c in ${(f)casks}; do
    brewfile_packages[cask:$c]=1
    brewfile_package_source[cask:$c]="$bf"
  done
  for t in ${(f)taps}; do
    brewfile_packages[tap:$t]=1
    brewfile_package_source[tap:$t]="$bf"
  done
done

# Get installed packages
installed_formulae=$(brew leaves --installed-on-request 2>/dev/null | sort -u)
installed_casks=$(brew list --cask --quiet 2>/dev/null | sort -u)
installed_taps=$(brew tap --quiet 2>/dev/null | sort -u)

# Find missing packages
typeset -a missing_formulae missing_casks missing_taps

for f in ${(f)installed_formulae}; do
  (( ${+brewfile_packages[brew:$f]} )) || missing_formulae+=("$f")
done

for c in ${(f)installed_casks}; do
  (( ${+brewfile_packages[cask:$c]} )) || missing_casks+=("$c")
done

for t in ${(f)installed_taps}; do
  (( ${+brewfile_packages[tap:$t]} )) || missing_taps+=("$t")
done

# Find packages in Brewfiles but not installed
typeset -a uninstalled_formulae uninstalled_casks uninstalled_taps

for bf in "${all_brewfiles[@]}"; do
  local file="$BREWFILE_DIR/Brewfile.$bf"
  [[ -f "$file" ]] || continue

  local formulae=$(grep -E '^brew "' "$file" 2>/dev/null | sed 's/brew "//' | sed 's/"$//' | sed 's/".*//' | sort -u)
  local casks=$(grep -E '^cask "' "$file" 2>/dev/null | sed 's/cask "//' | sed 's/"$//' | sort -u)
  local taps=$(grep -E '^tap "' "$file" 2>/dev/null | sed 's/tap "//' | sed 's/"$//' | sort -u)

  for f in ${(f)formulae}; do
    if [[ ! " ${(f)installed_formulae} " =~ " $f " ]]; then
      uninstalled_formulae+=("$f|$bf")
    fi
  done

  for c in ${(f)casks}; do
    if [[ ! " ${(f)installed_casks} " =~ " $c " ]]; then
      uninstalled_casks+=("$c|$bf")
    fi
  done

  for t in ${(f)taps}; do
    if [[ ! " ${(f)installed_taps} " =~ " $t " ]]; then
      uninstalled_taps+=("$t|$bf")
    fi
  done
done

# Count totals
missing_count=${#missing_formulae}+${#missing_casks}+${#missing_taps}
uninstalled_count=${#uninstalled_formulae}+${#uninstalled_casks}+${#uninstalled_taps}

if [[ $missing_count -eq 0 && $uninstalled_count -eq 0 ]]; then
  echo "✅ Brewfiles are fully in sync with installed packages!"
  exit 0
fi

echo "📊 Sync Summary:"
[[ $missing_count -gt 0 ]] && echo "  → $missing_count package(s) installed but not tracked"
[[ $uninstalled_count -gt 0 ]] && echo "  → $uninstalled_count package(s) in Brewfiles but not installed"
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

# Function to handle uninstalled packages
prompt_uninstalled() {
  local type=$1
  local package=$2
  local brewfile=$3

  # Show package info
  case $type in
    brew)
      local info=$(brew info "$package" 2>/dev/null | head -1)
      echo "📦 brew: $package (in Brewfile.$brewfile but not installed)"
      [[ -n $info ]] && echo "   $info"
      ;;
    cask)
      local info=$(brew info --cask "$package" 2>/dev/null | head -1)
      echo "🍺 cask: $package (in Brewfile.$brewfile but not installed)"
      [[ -n $info ]] && echo "   $info"
      ;;
    tap)
      echo "🔧 tap: $package (in Brewfile.$brewfile but not tapped)"
      ;;
  esac

  echo
  echo "Action:"
  echo "  [i] Install with brew"
  echo "  [r] Remove from Brewfile.$brewfile"
  echo "  [s] Skip"
  echo "  [q] Quit"
  echo

  local choice
  echo -n "Choice: "
  read -r choice

  case $choice in
    [Ii]*)
      echo "   📥 Installing $package..."
      case $type in
        brew)
          if brew install "$package"; then
            echo "   ✅ Installed"
          else
            echo "   ❌ Installation failed"
          fi
          ;;
        cask)
          if brew install --cask "$package"; then
            echo "   ✅ Installed"
          else
            echo "   ❌ Installation failed"
          fi
          ;;
        tap)
          if brew tap "$package"; then
            echo "   ✅ Tapped"
          else
            echo "   ❌ Tap failed"
          fi
          ;;
      esac
      echo
      ;;
    [Rr]*)
      local file="$BREWFILE_DIR/Brewfile.$brewfile"
      # Remove the line from Brewfile
      case $type in
        brew)
          sed -i.tmp "/^brew \"$package\"$/d" "$file"
          ;;
        cask)
          sed -i.tmp "/^cask \"$package\"$/d" "$file"
          ;;
        tap)
          sed -i.tmp "/^tap \"$package\"$/d" "$file"
          ;;
      esac
      rm -f "$file.tmp"
      echo "   🗑️  Removed from Brewfile.$brewfile"
      echo
      ;;
    [Qq]*)
      echo "   👋 Quitting"
      exit 0
      ;;
    *)
      echo "   ⏭️  Skipped"
      echo
      ;;
  esac
}

# Process missing packages (installed but not tracked)
if [[ $missing_count -gt 0 ]]; then
  echo "=== Phase 1: Packages installed but not in Brewfiles ==="
  echo

  for f in "${missing_formulae[@]}"; do
    prompt_brewfile_choice "brew" "$f"
  done

  for c in "${missing_casks[@]}"; do
    prompt_brewfile_choice "cask" "$c"
  done

  for t in "${missing_taps[@]}"; do
    prompt_brewfile_choice "tap" "$t"
  done
fi

# Process uninstalled packages (in Brewfiles but not installed)
if [[ $uninstalled_count -gt 0 ]]; then
  echo
  echo "=== Phase 2: Packages in Brewfiles but not installed ==="
  echo

  for item in "${uninstalled_formulae[@]}"; do
    local package="${item%|*}"
    local brewfile="${item#*|}"
    prompt_uninstalled "brew" "$package" "$brewfile"
  done

  for item in "${uninstalled_casks[@]}"; do
    local package="${item%|*}"
    local brewfile="${item#*|}"
    prompt_uninstalled "cask" "$package" "$brewfile"
  done

  for item in "${uninstalled_taps[@]}"; do
    local package="${item%|*}"
    local brewfile="${item#*|}"
    prompt_uninstalled "tap" "$package" "$brewfile"
  done
fi

echo "✨ Done! Review changes with: git diff $BREWFILE_DIR"
