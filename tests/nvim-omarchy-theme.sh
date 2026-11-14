#!/usr/bin/env bash
# Headless nvim follows a fake Omarchy theme directory, switches live, and falls back to tokyonight-night.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
omarchy=${OMARCHY_PATH:-/usr/share/omarchy}
lazy=${NVIM_TEST_LAZY:-$HOME/.local/share/nvim/lazy}
skip() { printf 'SKIP: %s\n' "$1"; exit 0; }
command -v nvim >/dev/null 2>&1 || skip "nvim is not installed"
for t in catppuccin catppuccin-latte gruvbox lumon; do
  [ -f "$omarchy/themes/$t/neovim.lua" ] || skip "no Omarchy theme $t"
done
for p in lazy.nvim tokyonight.nvim catppuccin gruvbox.nvim; do
  [ -d "$lazy/$p" ] || skip "plugin $p is not installed in $lazy"
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
render=$("$repo/scripts/render-home.sh" towerr "$tmp/render")
mkdir -p "$tmp/data/nvim/lazy" "$tmp/omarchy/themes" "$tmp/state" "$tmp/cache"
for p in lazy.nvim tokyonight.nvim catppuccin gruvbox.nvim; do
  cp -r "$lazy/$p" "$tmp/data/nvim/lazy/"
done
for t in catppuccin catppuccin-latte gruvbox lumon; do
  mkdir -p "$tmp/omarchy/themes/$t"
  cp "$omarchy/themes/$t/neovim.lua" "$tmp/omarchy/themes/$t/"
done

cat >"$tmp/init.lua" <<'EOF'
vim.opt.rtp:prepend(vim.fn.stdpath 'data' .. '/lazy/lazy.nvim')
_G.notes = {}
vim.notify = function(msg, level) table.insert(_G.notes, { msg = msg, level = level or vim.log.levels.INFO }) end
require('lazy').setup({ { import = 'plugins.colorscheme' } }, {
  install = { missing = false },
  checker = { enabled = false },
  change_detection = { enabled = false },
  rocks = { enabled = false },
})
EOF

cat >"$tmp/test.lua" <<'EOF'
local current = vim.env.HOME .. '/.local/state/omarchy/current'
local themes = vim.env.OMARCHY_PATH .. '/themes'
local function fail(msg)
  io.stderr:write('FAIL: ' .. msg .. ' (colors_name=' .. tostring(vim.g.colors_name) .. ')\n')
  for _, n in ipairs(_G.notes) do io.stderr:write('  notify ' .. n.level .. ': ' .. n.msg .. '\n') end
  vim.cmd 'cq 1'
end
local function expect(name, msg)
  if not vim.wait(3000, function() return vim.g.colors_name == name end, 20) then fail(msg) end
end
local function switch(theme)
  assert(os.execute(('rm -rf %q && mkdir -p %q && cp %q %q'):format(current .. '/theme', current .. '/theme',
    themes .. '/' .. theme .. '/neovim.lua', current .. '/theme/neovim.lua')) == 0)
  local f = assert(io.open(current .. '/theme.name', 'w'))
  f:write(theme .. '\n')
  f:close()
end
local function errors()
  for _, n in ipairs(_G.notes) do
    if n.level >= vim.log.levels.ERROR then return true end
  end
  return vim.v.errmsg ~= ''
end

local case = vim.env.CASE
if case == 'live' then
  expect('catppuccin-mocha', 'startup did not apply the Omarchy catppuccin theme')
  switch 'gruvbox'
  expect('gruvbox', 'live switch to gruvbox')
  switch 'catppuccin-latte'
  expect('catppuccin-latte', 'live switch to catppuccin-latte')
  if vim.o.background ~= 'light' then fail('catppuccin-latte left background=' .. vim.o.background) end
  _G.notes = {}
  switch 'lumon'
  expect('tokyonight-night', 'a theme whose plugin is missing must fall back')
  if #_G.notes ~= 1 or _G.notes[1].level ~= vim.log.levels.WARN then fail 'missing plugin should warn once' end
elseif case == 'empty' then
  expect('tokyonight-night', 'fallback without neovim.lua')
  if #_G.notes > 0 then fail 'fallback without neovim.lua should be silent' end
else
  expect('tokyonight-night', 'fallback without Omarchy')
  if #_G.notes > 0 then fail 'fallback without Omarchy should be silent' end
  local names = vim.tbl_keys(require('lazy.core.config').plugins)
  table.sort(names)
  if table.concat(names, ',') ~= 'lazy.nvim,tokyonight.nvim' then fail('unexpected plugins without Omarchy: ' .. table.concat(names, ',')) end
end
if errors() then fail('errors: ' .. vim.v.errmsg) end
vim.cmd 'qa!'
EOF

run() {
  local case=$1 home="$tmp/home-$1"
  mkdir -p "$home"
  case $case in
    live)
      mkdir -p "$home/.local/state/omarchy/current/theme"
      cp "$tmp/omarchy/themes/catppuccin/neovim.lua" "$home/.local/state/omarchy/current/theme/"
      echo catppuccin >"$home/.local/state/omarchy/current/theme.name"
      ;;
    empty) mkdir -p "$home/.local/state/omarchy/current/theme" ;;
  esac
  HOME="$home" CASE="$case" OMARCHY_PATH="$tmp/omarchy" XDG_CONFIG_HOME="$render/.config" \
    XDG_DATA_HOME="$tmp/data" XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache" \
    timeout 60 nvim --headless -u "$tmp/init.lua" -c "luafile $tmp/test.lua" </dev/null ||
    { printf 'FAIL: nvim case %s\n' "$case" >&2; exit 1; }
}

for case in live empty none; do run "$case"; done
printf 'PASS: nvim follows Omarchy themes (catppuccin, gruvbox, catppuccin-latte), falls back for lumon, empty and no Omarchy\n'
