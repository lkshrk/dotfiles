-- Personal input overrides, loaded after Omarchy's defaults.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input

-- us-mac and umlaut:lalt live in ~/.config/xkb; Right Alt stays AltGr for intl, so Compose goes to Menu.
hl.config({
  input = {
    kb_layout = "us-mac",
    kb_variant = "intl",
    kb_options = "compose:menu,umlaut:lalt,shift:both_capslock_cancel",
  },
})
