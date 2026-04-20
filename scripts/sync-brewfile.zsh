#!/usr/bin/env zsh
# sync-brewfile — Interactive bidirectional Brewfile sync
# 1. Installed but not in Brewfile → add to Brewfile
# 2. In Brewfile but not installed → install OR remove from Brewfile

set -euo pipefail

# Disable auto-continue - prompt for each package individually
unset LAST_BREWFILE_CHOICE LAST_CHOICE_TYPE

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
    # If formula has tap prefix (e.g., "atlassian/acli/acli"), mark tap as tracked
    if [[ "$f" =~ "^([^/]+)/([^/]+)/" ]]; then
      local tap_name="${match[1]}/${match[2]}"
      brewfile_packages[tap:$tap_name]=1
      brewfile_package_source[tap:$tap_name]="$bf"
      # Also store base name
      local base_name="${f##*/}"
      brewfile_packages[brew:$base_name]=1
      brewfile_package_source[brew:$base_name]="$bf"
    fi
  done
  for c in ${(f)casks}; do
    brewfile_packages[cask:$c]=1
    brewfile_package_source[cask:$c]="$bf"
    # If cask has tap prefix, mark tap as tracked
    if [[ "$c" =~ "^([^/]+)/([^/]+)/" ]]; then
      local tap_name="${match[1]}/${match[2]}"
      brewfile_packages[tap:$tap_name]=1
      brewfile_package_source[tap:$tap_name]="$bf"
      # Also store base name
      local base_name="${c##*/}"
      brewfile_packages[cask:$base_name]=1
      brewfile_package_source[cask:$base_name]="$bf"
    fi
  done
  for t in ${(f)taps}; do
    brewfile_packages[tap:$t]=1
    brewfile_package_source[tap:$t]="$bf"
  done
done

# Get installed packages using brew bundle dump (clean and accurate)
TEMP_BREWFILE=$(mktemp)
trap "rm -f $TEMP_BREWFILE" EXIT
rm -f "$TEMP_BREWFILE"  # Remove empty file so brew bundle dump can create it

brew bundle dump --file "$TEMP_BREWFILE" 2>/dev/null || true

# Parse the dumped Brewfile
installed_formulae=$(grep -E '^brew "' "$TEMP_BREWFILE" 2>/dev/null | sed 's/brew "//' | sed 's/"$//' | sed 's/".*//' | sort -u)
installed_casks=$(grep -E '^cask "' "$TEMP_BREWFILE" 2>/dev/null | sed 's/cask "//' | sed 's/"$//' | sort -u)
installed_taps=$(grep -E '^tap "' "$TEMP_BREWFILE" 2>/dev/null | sed 's/tap "//' | sed 's/"$//' | sort -u)

# Build lookup maps for installed packages
typeset -A installed_formulae_map installed_casks_map installed_taps_map
for f in ${(f)installed_formulae}; do
  installed_formulae_map[$f]=1
  # Also store base name for tap-prefixed packages
  if [[ "$f" =~ "^([^/]+)/([^/]+)/" ]]; then
    local base_name="${f##*/}"
    installed_formulae_map[$base_name]=1
  fi
done
for c in ${(f)installed_casks}; do
  installed_casks_map[$c]=1
  # Also store base name for tap-prefixed packages
  if [[ "$c" =~ "^([^/]+)/([^/]+)/" ]]; then
    local base_name="${c##*/}"
    installed_casks_map[$base_name]=1
  fi
done
for t in ${(f)installed_taps}; do
  installed_taps_map[$t]=1
done

# Find missing packages (installed but not in Brewfiles)
typeset -a missing_formulae missing_casks missing_taps

for f in ${(f)installed_formulae}; do
  (( ${+brewfile_packages[brew:$f]} )) || missing_formulae+=("$f")
done

for c in ${(f)installed_casks}; do
  (( ${+brewfile_packages[cask:$c]} )) || missing_casks+=("$c")
done

for t in ${(f)installed_taps}; do
  # Skip default taps
  [[ "$t" == "homebrew/core" ]] && continue
  [[ "$t" == "homebrew/cask" ]] && continue
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
    (( ${+installed_formulae_map[$f]} )) || uninstalled_formulae+=("$f|$bf")
  done

  for c in ${(f)casks}; do
    (( ${+installed_casks_map[$c]} )) || uninstalled_casks+=("$c|$bf")
  done

  for t in ${(f)taps}; do
    # Skip default taps
    [[ "$t" == "homebrew/core" ]] && continue
    [[ "$t" == "homebrew/cask" ]] && continue
    (( ${+installed_taps_map[$t]} )) || uninstalled_taps+=("$t|$bf")
  done
done

# Count totals
missing_count=$((${#missing_formulae}+${#missing_casks}+${#missing_taps}))
uninstalled_count=$((${#uninstalled_formulae}+${#uninstalled_casks}+${#uninstalled_taps}))

# Count total tracked packages for sync stats
tracked_formulae=0
tracked_casks=0
tracked_taps=0
for key in ${(k)brewfile_packages}; do
  case $key in
    brew:*) ((tracked_formulae++)) ;;
    cask:*) ((tracked_casks++)) ;;
    tap:*) ((tracked_taps++)) ;;
  esac || true
done

# Count packages that are in sync (tracked AND installed)
in_sync_count=$((tracked_formulae - ${#uninstalled_formulae} + tracked_casks - ${#uninstalled_casks} + tracked_taps - ${#uninstalled_taps}))

if [[ $missing_count -eq 0 && $uninstalled_count -eq 0 ]]; then
  echo "✅ Brewfiles are fully in sync with installed packages!"
  exit 0
fi

echo "📊 Sync Summary:"
echo "  → $in_sync_count package(s) in sync"
[[ $missing_count -gt 0 ]] && echo "  → $missing_count package(s) installed but not in Brewfiles"
[[ $uninstalled_count -gt 0 ]] && echo "  → $uninstalled_count package(s) in Brewfiles but not installed"
echo

# Ask how to proceed
echo "How would you like to sync?"
echo "  [a] Install all & add all (automatic)"
echo "  [d] Decide for each package (interactive)"
echo

local sync_mode
echo -n "Choice: "
read -k 1 sync_mode
echo
echo

if [[ "$sync_mode" =~ "[Aa]" ]]; then
  echo "🚀 Automatic mode: installing all & adding all..."
  echo

  # Install all uninstalled packages
  if [[ $uninstalled_count -gt 0 ]]; then
    echo "=== Installing uninstalled packages ==="

    for item in "${uninstalled_taps[@]}"; do
      local package="${item%|*}"
      echo "  → Tapping $package..."
      brew tap "$package" 2>/dev/null || echo "    ⚠️  Failed to tap $package"
    done

    for item in "${uninstalled_formulae[@]}"; do
      local package="${item%|*}"
      echo "  → Installing brew: $package..."
      brew install "$package" 2>/dev/null || echo "    ⚠️  Failed to install $package"
    done

    for item in "${uninstalled_casks[@]}"; do
      local package="${item%|*}"
      echo "  → Installing cask: $package..."
      brew install --cask "$package" 2>/dev/null || echo "    ⚠️  Failed to install $package"
    done

    echo
  fi

  # Add all missing packages to relevant Brewfiles
  if [[ $missing_count -gt 0 ]]; then
    echo "=== Adding missing packages to Brewfiles ==="

    # Use first relevant Brewfile (or base if none)
    local target_brewfile="${relevant_brewfiles[1]:-base}"
    local file="$BREWFILE_DIR/Brewfile.$target_brewfile"
    echo "  → Adding to Brewfile.$target_brewfile"
    echo

    for f in "${missing_formulae[@]}"; do
      echo "brew \"$f\"" >> "$file"
      echo "  ✅ Added brew: $f"
    done

    for c in "${missing_casks[@]}"; do
      echo "cask \"$c\"" >> "$file"
      echo "  ✅ Added cask: $c"
    done

    for t in "${missing_taps[@]}"; do
      echo "tap \"$t\"" >> "$file"
      echo "  ✅ Added tap: $t"
    done

    echo
  fi

  echo "✨ Automatic sync complete!"
  echo
  exit 0
fi

echo "🔍 Interactive mode: deciding for each package..."
echo
echo

# Function to prompt for Brewfile selection
prompt_brewfile_choice() {
  local type=$1
  local package=$2

  # Show package info
  case $type in
    brew)
      local info=$(brew info "$package" 2>/dev/null)
      local desc=$(echo "$info" | sed -n '2p' | sed 's/:$//' | sed 's/^[[:space:]]*//')
      echo "📌 brew: $package"
      [[ -n $desc ]] && echo "   $desc"
      ;;
    cask)
      local info=$(brew info --cask "$package" 2>/dev/null)
      local desc=$(echo "$info" | sed -n '2p' | sed 's/:$//' | sed 's/^[[:space:]]*//')
      echo "🍺 cask: $package"
      [[ -n $desc ]] && echo "   $desc"
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

  echo "  [u] Uninstall from system"
  echo "  [s] Skip"
  echo "  [q] Quit"
  echo

  local -A choice_map
  i=1
  # Build choice_map in the same order as the menu display
  for bf in "${relevant_brewfiles[@]}"; do
    choice_map[$i]=$bf
    ((i++))
  done
  for bf in "${all_brewfiles[@]}"; do
    [[ " ${relevant_brewfiles[@]} " =~ " ${bf} " ]] && continue
    choice_map[$i]=$bf
    ((i++))
  done

  local choice
  echo -n "Choice: "
  read -k 1 choice  # Read single character without Enter

  case $choice in
    [Qq]*)
      echo "   👋 Quitting"
      exit 0
      ;;
    [Uu]*)
      echo "   🗑️  Uninstalling $package..."
      case $type in
        brew)
          if brew uninstall "$package"; then
            echo "   ✅ Uninstalled"
          else
            echo "   ❌ Uninstallation failed"
          fi
          ;;
        cask)
          if brew uninstall --cask "$package"; then
            echo "   ✅ Uninstalled"
          else
            echo "   ❌ Uninstallation failed"
          fi
          ;;
        tap)
          # First uninstall any formulae/casks from this tap
          local tap_packages=$(brew list --formula --quiet | grep "^${package//\//\\/}/" 2>/dev/null || true)
          local tap_casks=$(brew list --cask --quiet | grep "^${package//\//\\/}/" 2>/dev/null || true)

          if [[ -n "$tap_packages" ]] || [[ -n "$tap_casks" ]]; then
            echo "   ⚠️  Tap contains installed packages, uninstalling first..."
            for p in ${(f)tap_packages}; do
              echo "      → Uninstalling $p..."
              brew uninstall "$p" 2>/dev/null || true
            done
            for c in ${(f)tap_casks}; do
              echo "      → Uninstalling $c..."
              brew uninstall --cask "$c" 2>/dev/null || true
            done
          fi

          if brew untap "$package"; then
            echo "   ✅ Untapped"
          else
            echo "   ❌ Untap failed"
          fi
          ;;
      esac
      echo
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
      local info=$(brew info "$package" 2>/dev/null)
      local desc=$(echo "$info" | sed -n '2p' | sed 's/:$//' | sed 's/^[[:space:]]*//')
      echo "📦 brew: $package (in Brewfile.$brewfile but not installed)"
      [[ -n $desc ]] && echo "   $desc"
      ;;
    cask)
      local info=$(brew info --cask "$package" 2>/dev/null)
      local desc=$(echo "$info" | sed -n '2p' | sed 's/:$//' | sed 's/^[[:space:]]*//')
      echo "🍺 cask: $package (in Brewfile.$brewfile but not installed)"
      [[ -n $desc ]] && echo "   $desc"
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
  read -k 1 choice  # Read single character without Enter

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

  # Taps first (required before formulae/casks can be installed)
  for item in "${uninstalled_taps[@]}"; do
    local package="${item%|*}"
    local brewfile="${item#*|}"
    prompt_uninstalled "tap" "$package" "$brewfile"
  done

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
fi

echo "✨ Done! Review changes with: git diff $BREWFILE_DIR"
echo

# Check if there are Brewfile changes to commit
local changed_brewfiles=$(git diff --name-only "$BREWFILE_DIR" 2>/dev/null)
if [[ -n "$changed_brewfiles" ]]; then
  # Stage only the changed Brewfiles
  echo "$changed_brewfiles" | xargs git add 2>/dev/null || true

  # Create commit with today's date
  local today=$(date +"%Y-%m-%d")
  local commit_msg="chore(dotsync): brew ($today)"

  if git commit -m "$commit_msg" 2>/dev/null; then
    echo "✅ Changes committed: $commit_msg"
  else
    echo "⚠️  Failed to commit changes (check git status)"
  fi
else
  echo "ℹ️  No Brewfile changes to commit"
fi
