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
3. **Cream Rosé Pine** — installs a same-slug user theme overlay
   (`themes/rose-pine/colors.toml` → `~/.config/omarchy/themes/rose-pine/`) that
   warms the stock light backgrounds (`#faf4ed` etc.) into a soft cream that's
   easier on the eyes, and re-applies it if Rosé Pine is the active theme. The
   rest of the palette (foreground, accent, ANSI colors) is stock Rosé Pine.
   Reversible: delete that file and run `omarchy theme set rose-pine`.
4. **Opaque top bar** — sets `bar.transparent = false` in `shell.json`. A
   transparent bar renders its icons over the wallpaper, which makes them
   unreadable on light themes; a solid themed background keeps them visible.
5. **[Wallpaper Roulette](https://github.com/keegan-sucks/omarchy-wallpaper-roulette)** —
   installs the plugin and points it at your wallpapers, rotating every 30
   minutes and switching the theme to match each wallpaper.
6. **[Flowstate](https://github.com/keegan-sucks/omarchy-flowstate)** — installs
   the focus-timer plugin.
7. **Firefox over Chromium** — ensures Firefox is installed and the default
   browser, removes Chromium-backed web apps (Discord, etc.), and removes
   Chromium if present.
8. **Community plugins** — installs
   [AirPods](https://github.com/thisisgm/omarchy-pods),
   [Omamail](https://github.com/huacnlee/omamail), and
   [MenuVitals](https://github.com/ierror/menuvitals).

Omamail and AirPods need a one-time setup of their own — see each plugin's
README.

## License

MIT
