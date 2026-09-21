# omarchy-setup

Keegan's [Omarchy](https://omarchy.org) preferences in one call. Run it on a
fresh Omarchy machine (or re-run any time — every step is idempotent).

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/keegan-sucks/omarchy-setup/main/setup.sh)
```

or

```bash
git clone https://github.com/keegan-sucks/omarchy-setup
./omarchy-setup/setup.sh
```

Run it in a terminal — installing or removing Firefox/Chromium may prompt for
your password.

## What it does

1. **Wallpapers** — downloads [keegan-sucks/wallpaper](https://github.com/keegan-sucks/wallpaper)
   into `~/.config/omarchy/backgrounds/<theme>/`, the standard Omarchy user
   background location, so they show up in the background switcher.
2. **Hide stock wallpapers** — installs a `theme-set` hook so that, for any
   theme you have your own wallpapers for, only yours appear in the switcher.
   Themes you haven't customized keep their stock wallpapers. Fully reversible:
   delete `~/.config/omarchy/hooks/theme-set.d/prune-stock-backgrounds.sh` and
   the next theme switch brings the stock ones back.
3. **Cream light themes** — installs same-slug user theme overlays
   (`themes/<slug>/colors.toml` → `~/.config/omarchy/themes/<slug>/`) that warm
   the stock light backgrounds into a soft cream that's easier on the eyes, and
   re-applies whichever one is the active theme. Currently covers **Rosé Pine**
   (`#faf4ed` → cream) and **Catppuccin Latte** (`#eff1f5` → cream). The rest of
   each palette (foreground, accent, ANSI colors) is left stock. Reversible:
   delete the overlay file and run `omarchy theme set <slug>`.
4. **Opaque top bar** — sets `bar.transparent = false` in `shell.json`. A
   transparent bar renders its icons over the wallpaper, which makes them
   unreadable on light themes; a solid themed background keeps them visible.
5. **Idle timeouts** — screensaver after 5 minutes, lock after 10 (twice the
   Omarchy defaults).
6. **Plugins** — installs
   [Wallpaper Roulette](https://github.com/keegan-sucks/omarchy-wallpaper-roulette)
   (pointed at your wallpapers, rotating every 30 minutes and switching the
   theme to match),
   [Flowstate](https://github.com/keegan-sucks/omarchy-flowstate) (focus timer),
   [AirPods](https://github.com/thisisgm/omarchy-pods),
   [RSS-Feeder](https://github.com/keegan-sucks/rss-feeder) (my fork of
   [rss-reeder](https://github.com/sanjyay/rss-reeder)),
   [Look Up](https://github.com/keegan-sucks/omarchy-lookup) (dictionary popup),
   [MenuVitals](https://github.com/ierror/menuvitals) (system vitals),
   [Leaf Reader](https://github.com/dlpwaters/omarchy-ebook-reader) (ebooks),
   [OmaTasks for Todoist](https://github.com/crmne/omatasks),
   [GitHub](https://github.com/robzolkos/omarchy-github) (notifications inbox),
   and [hyprmoncfg](https://github.com/crmne/omarchy-hyprmoncfg) (monitor
   profiles).
7. **Lock screen wallpaper** — the stock lock screen blurs the wallpaper into a
   flat color. This clones the lock plugin (`omarchy plugin clone omarchy.lock`)
   and drops the blur to a light one, so the current background shows behind
   the password box. Needs `omarchy restart shell` to apply. Reversible:
   `omarchy plugin remove $USER.lock`.
8. **Firefox over Chromium** — ensures Firefox is installed and the default
   browser, removes Chromium-backed web apps (Discord, etc.), and removes
   Chromium if present.
9. **Steam window** — writes `~/.config/hypr/steam.lua` to pin Steam's desktop
   UI scale (Omarchy lets it auto-inflate on the HiDPI laptop panel) and tile
   the main window instead of the stock small floating box. Restart Steam
   afterwards for the new scale to apply; adjust the scale in the file or in
   Steam > Settings > Accessibility.
10. **Screensaver mouse dismiss** — installs and autostarts a small watcher
    that ends the screensaver on mouse movement (stock only exits on a key
    press).

AirPods needs a one-time setup of its own — see the plugin's README.

## License

MIT
