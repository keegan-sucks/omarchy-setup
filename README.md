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
3. **[Wallpaper Roulette](https://github.com/keegan-sucks/omarchy-wallpaper-roulette)** —
   installs the plugin and points it at your wallpapers, rotating every 30
   minutes and switching the theme to match each wallpaper.
4. **[Flowstate](https://github.com/keegan-sucks/omarchy-flowstate)** — installs
   the focus-timer plugin.
5. **Firefox over Chromium** — ensures Firefox is installed and the default
   browser, removes Chromium-backed web apps (Discord, etc.), and removes
   Chromium if present.
6. **Community plugins** — installs
   [AirPods](https://github.com/thisisgm/omarchy-pods),
   [RSS-Feeder](https://github.com/keegan-sucks/rss-feeder) (my fork of
   [rss-reeder](https://github.com/sanjyay/rss-reeder), with YouTube Shorts
   filtering and per-feed category editing), and
   [MenuVitals](https://github.com/ierror/menuvitals).
7. **Steam window** — writes `~/.config/hypr/steam.lua` to pin Steam's desktop
   UI scale (Omarchy lets it auto-inflate on the HiDPI laptop panel) and tile
   the main window instead of the stock small floating box. Restart Steam
   afterwards for the new scale to apply; adjust the scale in the file or in
   Steam > Settings > Accessibility.

AirPods needs a one-time setup of its own — see the plugin's README.

## License

MIT
