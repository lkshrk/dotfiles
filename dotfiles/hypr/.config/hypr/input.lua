-- us-mac lives in ~/.config/xkb (umlauts on AltGr, sent by keyd for Left Alt); Right Alt stays AltGr for intl, so Compose goes to Menu.
hl.config({
  input = {
    kb_layout = "us-mac",
    kb_variant = "intl",
    kb_options = "compose:menu,shift:both_capslock_cancel",
  },
})
