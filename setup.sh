#!/usr/bin/env bash
#
# omarchy-setup — Keegan's Omarchy preferences in one call.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/keegan-sucks/omarchy-setup/main/setup.sh)
#
# or:  git clone https://github.com/keegan-sucks/omarchy-setup && ./omarchy-setup/setup.sh
#
# Every step is idempotent — re-running only fixes what's missing. Run it in a
# terminal: installing/removing packages (Firefox/Chromium) may prompt for sudo.

set -uo pipefail

# ---- config ---------------------------------------------------------------

WALLPAPER_REPO="https://github.com/keegan-sucks/wallpaper.git"
BG_DEST="$HOME/.config/omarchy/backgrounds"
ROULETTE_ID="io.github.keegan-sucks.wallpaper-roulette"
ROULETTE_REPO="https://github.com/keegan-sucks/omarchy-wallpaper-roulette"

# Cream overlays: warm the stock light-theme backgrounds into cream so they are
# easier on the eyes. Each is installed as a same-slug user theme that wins on
# top of the stock theme when that theme is applied.
# Format: "theme-slug|Display Name" (the display name is what `omarchy theme
# current` prints, used to decide whether to re-apply now).
SETUP_RAW_BASE="https://raw.githubusercontent.com/keegan-sucks/omarchy-setup/main"
THEME_OVERLAYS=(
  "rose-pine|Rose Pine"
  "catppuccin-latte|Catppuccin Latte"
)

# Idle timeouts (seconds since idle began), written into shell.json. Twice the
# Omarchy defaults (150 / 300): screensaver after 5 min, lock after 10 min.
IDLE_SCREENSAVER_SECONDS=300
IDLE_LOCK_SECONDS=600

# Watcher that ends the terminal screensaver on mouse movement (the stock one
# only exits on keyboard input). Installed to ~/.local/bin and autostarted.
WATCH_REL="bin/omarchy-screensaver-mouse-watch"
WATCH_DEST="$HOME/.local/bin/omarchy-screensaver-mouse-watch"

# Blur strength for the lock screen wallpaper (Omarchy's stock value is 128,
# which smears the wallpaper into a flat color). Lower = sharper.
LOCK_BLUR_MAX=16

# Plugins: "repo-url|id|label" (Wallpaper Roulette is installed separately
# because it also needs configuring).
PLUGINS=(
  "https://github.com/keegan-sucks/omarchy-flowstate|io.github.keegan-sucks.flowstate|Flowstate"
  "https://github.com/thisisgm/omarchy-pods|io.github.thisisgm.omapods|AirPods (omapods)"
  "https://github.com/keegan-sucks/rss-feeder|io.github.keegan-sucks.rss-feeder|RSS-Feeder"
  "https://github.com/keegan-sucks/omarchy-lookup|io.github.keegan-sucks.lookup|Look Up"
  "https://github.com/ierror/menuvitals|io.github.ierror.menuvitals|MenuVitals"
  "https://github.com/dlpwaters/omarchy-ebook-reader|io.github.dlpwaters.ebook-reader|Leaf Reader"
  "https://github.com/crmne/omatasks|crmne.todoist|OmaTasks for Todoist"
  "https://github.com/robzolkos/omarchy-github|robzolkos.github|GitHub"
  "https://github.com/crmne/omarchy-hyprmoncfg|crmne.hyprmoncfg|hyprmoncfg"
)

IMG_GLOB=(-iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp')

# ---- output helpers -------------------------------------------------------

c_blue=$'\033[1;34m'; c_grn=$'\033[1;32m'; c_yel=$'\033[1;33m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
step() { printf '\n%s==>%s %s\n' "$c_blue" "$c_off" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$c_grn" "$c_off" "$*"; }
skip() { printf '  %s·%s %s\n' "$c_dim" "$c_off" "$*"; }
warn() { printf '  %s!%s %s\n' "$c_yel" "$c_off" "$*" >&2; }

require_omarchy() {
  command -v omarchy >/dev/null 2>&1 || { warn "This is not an Omarchy system (omarchy not found)."; exit 1; }
}

has_images() { [[ -n "$(find -L "$1" -maxdepth 1 -type f \( "${IMG_GLOB[@]}" \) -print -quit 2>/dev/null)" ]]; }

# ---- 1. wallpapers --------------------------------------------------------

install_wallpapers() {
  step "Installing wallpapers into ${BG_DEST/#$HOME/\~}"
  local tmp; tmp="$(mktemp -d)"
  if ! git clone --depth 1 --quiet "$WALLPAPER_REPO" "$tmp/wallpaper"; then
    warn "Could not clone $WALLPAPER_REPO"; rm -rf "$tmp"; return 1
  fi
  mkdir -p "$BG_DEST"
  local d slug n
  for d in "$tmp"/wallpaper/*/; do
    [[ -d $d ]] || continue
    has_images "$d" || continue           # skip non-theme dirs
    slug="$(basename "$d")"
    mkdir -p "$BG_DEST/$slug"
    find -L "$d" -maxdepth 1 -type f \( "${IMG_GLOB[@]}" \) -exec cp -f {} "$BG_DEST/$slug/" \;
    n="$(find -L "$BG_DEST/$slug" -maxdepth 1 -type f \( "${IMG_GLOB[@]}" \) | wc -l)"
    ok "$slug ($n wallpapers)"
  done
  rm -rf "$tmp"
}

# ---- 1b. hide stock wallpapers via a theme-set hook -----------------------

install_prune_hook() {
  step "Installing theme-set hook to hide stock wallpapers"
  # omarchy-hook-install keeps the source file's basename, so build it with the
  # final name inside a temp dir (a bare mktemp file would install as tmp.XXXX
  # and re-runs would pile up new copies).
  local tmpd; tmpd="$(mktemp -d)"
  local tmp="$tmpd/prune-stock-backgrounds.sh"
  cat > "$tmp" <<'HOOK'
#!/bin/bash
# Installed by omarchy-setup. For any theme the user has their own wallpapers
# for (under ~/.config/omarchy/backgrounds/<slug>/), drop the stock backgrounds
# that Omarchy stages for the theme, so only the user's wallpapers show in the
# background switcher. Themes without user wallpapers are left untouched, so
# they are never left empty. Operates only on regenerated user state, never on
# the read-only system files, so it is fully reversible: remove this hook and
# the next theme switch restores the stock wallpapers.
set -uo pipefail
slug="${1:-}"
[[ -n $slug ]] || exit 0
user_bg="$HOME/.config/omarchy/backgrounds/$slug"
staged="$HOME/.local/state/omarchy/current/theme/backgrounds"
cur_link="$HOME/.local/state/omarchy/current/background"
glob=(-iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.bmp' -o -iname '*.webp')
# Only act when the user actually has wallpapers for this theme.
[[ -n "$(find -L "$user_bg" -maxdepth 1 -type f \( "${glob[@]}" \) -print -quit 2>/dev/null)" ]] || exit 0
[[ -d $staged ]] || exit 0
find "$staged" -maxdepth 1 -type f \( "${glob[@]}" \) -delete 2>/dev/null || true
# If the just-selected background was a stock one we removed, repoint to a user one.
cur="$(readlink -f "$cur_link" 2>/dev/null || true)"
if [[ ! -e $cur ]]; then
  newbg="$(find -L "$user_bg" -maxdepth 1 -type f \( "${glob[@]}" \) 2>/dev/null | sort | head -1)"
  [[ -n $newbg ]] && omarchy-theme-bg-set "$newbg" >/dev/null 2>&1 || true
fi
exit 0
HOOK
  if omarchy hook install theme-set "$tmp" >/dev/null 2>&1 \
     || { mkdir -p "$HOME/.config/omarchy/hooks/theme-set.d" \
          && cp "$tmp" "$HOME/.config/omarchy/hooks/theme-set.d/prune-stock-backgrounds.sh" \
          && chmod 755 "$HOME/.config/omarchy/hooks/theme-set.d/prune-stock-backgrounds.sh"; }; then
    ok "theme-set.d/prune-stock-backgrounds.sh"
  else
    warn "Could not install theme-set hook"
  fi
  rm -rf "$tmpd"
}

# ---- 1c. cream light-theme overlays ---------------------------------------

install_theme_overlays() {
  step "Installing cream light-theme overlays"
  local script_dir current
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
  current="$(omarchy theme current 2>/dev/null)"

  local entry slug name rel dest src
  for entry in "${THEME_OVERLAYS[@]}"; do
    IFS='|' read -r slug name <<<"$entry"
    rel="themes/$slug/colors.toml"
    dest="$HOME/.config/omarchy/themes/$slug/colors.toml"

    # Source from the local clone when run that way, else fetch from the repo
    # (the setup.sh curl one-liner has no sibling files).
    src=""
    [[ -n $script_dir && -f "$script_dir/$rel" ]] && src="$script_dir/$rel"

    mkdir -p "$(dirname "$dest")"
    if [[ -n $src ]]; then
      cp -f "$src" "$dest"
    elif ! curl -fsSL "$SETUP_RAW_BASE/$rel" -o "$dest"; then
      warn "Could not fetch the cream $name overlay"; continue
    fi
    ok "$rel (cream backgrounds)"

    # Re-apply so it takes effect now when this is the active theme; otherwise
    # it applies automatically the next time the theme is selected.
    if [[ "$current" == "$name" ]]; then
      if omarchy theme set "$slug" >/dev/null 2>&1; then
        ok "Applied to the active $name theme"
      else
        warn "Installed; apply it with: omarchy theme set $slug"
      fi
    else
      skip "Applies the next time you select $name"
    fi
  done
}

# ---- 1d. make the top bar opaque ------------------------------------------

set_bar_opaque() {
  step "Making the top bar opaque"
  # A transparent bar renders its icons over the wallpaper, which makes them
  # unreadable on light themes. Force a solid, themed bar background.
  local shell_json="$HOME/.config/omarchy/shell.json"
  [[ -f $shell_json ]] || { skip "No shell.json yet — Omarchy default is already opaque"; return 0; }
  if [[ "$(jq -r '.bar.transparent' "$shell_json" 2>/dev/null)" == "false" ]]; then
    skip "Bar already opaque"
    return 0
  fi
  local tmp; tmp="$(mktemp)"
  if jq '.bar.transparent = false' "$shell_json" > "$tmp" 2>/dev/null && [[ -s $tmp ]]; then
    cp "$shell_json" "$shell_json.bak.$(date +%s)"
    mv "$tmp" "$shell_json"
    ok "bar.transparent = false"
  else
    rm -f "$tmp"
    warn "Could not set bar.transparent (edit shell.json by hand)"
  fi
}

# ---- 1e. idle timeouts ----------------------------------------------------

set_idle_timeouts() {
  step "Setting idle timeouts (screensaver ${IDLE_SCREENSAVER_SECONDS}s, lock ${IDLE_LOCK_SECONDS}s)"
  local shell_json="$HOME/.config/omarchy/shell.json"
  if [[ ! -f $shell_json ]]; then
    mkdir -p "$(dirname "$shell_json")"
    printf '{\n  "version": 1,\n  "idle": {\n    "screensaver": %d,\n    "lock": %d\n  }\n}\n' \
      "$IDLE_SCREENSAVER_SECONDS" "$IDLE_LOCK_SECONDS" > "$shell_json"
    ok "Created shell.json with screensaver=${IDLE_SCREENSAVER_SECONDS}s lock=${IDLE_LOCK_SECONDS}s"
    return 0
  fi
  local cur_ss cur_lock
  cur_ss="$(jq -r '.idle.screensaver // empty' "$shell_json" 2>/dev/null)"
  cur_lock="$(jq -r '.idle.lock // empty' "$shell_json" 2>/dev/null)"
  if [[ $cur_ss == "$IDLE_SCREENSAVER_SECONDS" && $cur_lock == "$IDLE_LOCK_SECONDS" ]]; then
    skip "Idle timeouts already screensaver=${IDLE_SCREENSAVER_SECONDS}s lock=${IDLE_LOCK_SECONDS}s"
    return 0
  fi
  local tmp; tmp="$(mktemp)"
  if jq --argjson s "$IDLE_SCREENSAVER_SECONDS" --argjson l "$IDLE_LOCK_SECONDS" \
        '.idle = (.idle // {}) | .idle.screensaver = $s | .idle.lock = $l' \
        "$shell_json" > "$tmp" 2>/dev/null && [[ -s $tmp ]]; then
    cp "$shell_json" "$shell_json.bak.$(date +%s)"
    mv "$tmp" "$shell_json"
    ok "idle.screensaver=${IDLE_SCREENSAVER_SECONDS}s, idle.lock=${IDLE_LOCK_SECONDS}s"
  else
    rm -f "$tmp"
    warn "Could not set idle timeouts (edit shell.json by hand)"
  fi
}

# ---- plugin install helper ------------------------------------------------

plugin_installed() { omarchy plugin list --json 2>/dev/null | jq -e --arg id "$1" 'any(.[]; .id == $id)' >/dev/null 2>&1; }

add_plugin() { # url  id  label
  local url="$1" id="$2" label="$3"
  if plugin_installed "$id"; then
    skip "$label already installed"
    return 0
  fi
  if omarchy plugin add "$url" --enable --yes >/dev/null 2>&1; then
    ok "$label"
  elif omarchy plugin add "$url" --yes >/dev/null 2>&1; then
    # Installed but could not auto-enable (e.g. shell not running).
    omarchy plugin enable "$id" >/dev/null 2>&1 || true
    ok "$label (installed; enable in the bar if needed)"
  else
    warn "Failed to install $label from $url"
    return 1
  fi
}

# ---- 2. wallpaper roulette ------------------------------------------------

install_roulette() {
  step "Installing Wallpaper Roulette plugin"
  add_plugin "$ROULETTE_REPO" "$ROULETTE_ID" "Wallpaper Roulette" || return 1
  # Point it at the wallpapers we just installed and set a 30-minute interval.
  local shell_json="$HOME/.config/omarchy/shell.json"
  [[ -f $shell_json ]] || return 0
  local tmp; tmp="$(mktemp)"
  if jq --arg id "$ROULETTE_ID" --arg dir "$BG_DEST" '
        walk(if type=="object" and (.id? == $id)
             then . + {wallpaperDir: $dir, intervalMinutes: 30, autoEnabled: true}
             else . end)
      ' "$shell_json" > "$tmp" 2>/dev/null && [[ -s $tmp ]]; then
    cp "$shell_json" "$shell_json.bak.$(date +%s)"
    mv "$tmp" "$shell_json"
    ok "Configured to rotate ${BG_DEST/#$HOME/\~} every 30 min"
  else
    rm -f "$tmp"
    warn "Could not write wallpaperDir into shell.json (set it in the widget settings)"
  fi
}

# ---- 4. firefox over chromium ---------------------------------------------

setup_browser() {
  step "Firefox as the browser (removing Chromium)"
  if command -v firefox >/dev/null 2>&1 || pacman -Q firefox >/dev/null 2>&1; then
    skip "Firefox already installed"
  else
    omarchy-install-browser firefox && ok "Installed Firefox" || warn "Firefox install failed"
  fi
  if [[ "$(omarchy-default-browser 2>/dev/null)" == "firefox" ]]; then
    skip "Firefox already the default browser"
  else
    omarchy-default-browser firefox >/dev/null 2>&1 && ok "Firefox set as default" || warn "Could not set default browser"
  fi
  # Chromium-backed web apps (Discord, etc.) break without Chromium — remove them.
  local before after
  before="$(find "$HOME/.local/share/applications" -maxdepth 1 -name '*.desktop' 2>/dev/null | wc -l)"
  omarchy-webapp-remove-all >/dev/null 2>&1 || true
  after="$(find "$HOME/.local/share/applications" -maxdepth 1 -name '*.desktop' 2>/dev/null | wc -l)"
  if (( before > after )); then ok "Removed $((before - after)) Chromium web app(s)"; else skip "No Chromium web apps to remove"; fi
  # Remove Chromium itself if present.
  if pacman -Q chromium >/dev/null 2>&1; then
    if omarchy-remove-browser chromium >/dev/null 2>&1 || omarchy pkg remove chromium >/dev/null 2>&1; then
      ok "Removed Chromium"
    else
      warn "Chromium is installed but removal failed — run: omarchy remove browser chromium"
    fi
  else
    skip "Chromium not installed"
  fi
}

# ---- plugins ---------------------------------------------------------------

install_plugins() {
  step "Installing plugins"
  local entry url id label
  for entry in "${PLUGINS[@]}"; do
    IFS='|' read -r url id label <<<"$entry"
    add_plugin "$url" "$id" "$label"
  done
}

# ---- lock screen: show the wallpaper behind the password box --------------

configure_lock_screen() {
  step "Lock screen: lightly blurred wallpaper behind the password box"
  # The stock lock screen already draws the current wallpaper, but blurs it so
  # hard it reads as a flat color. Built-in plugins can't be edited in place, so
  # clone the lock plugin (the clone survives Omarchy updates) and soften the
  # blur there. Patching the clone, rather than shipping a copy of LockView.qml,
  # keeps whatever else upstream has changed.
  local lock_id="${USER:-$(id -un)}.lock"
  local view="$HOME/.config/omarchy/plugins/$lock_id/LockView.qml"
  if [[ ! -f $view ]]; then
    if ! omarchy plugin clone omarchy.lock >/dev/null 2>&1 || [[ ! -f $view ]]; then
      warn "Could not clone the lock plugin (omarchy plugin clone omarchy.lock)"
      return 1
    fi
    ok "Cloned omarchy.lock to $lock_id"
  fi
  if grep -qE "^[[:space:]]*blurMax: $LOCK_BLUR_MAX\$" "$view"; then
    skip "Lock screen blur already $LOCK_BLUR_MAX"
    return 0
  fi
  if ! grep -qE '^[[:space:]]*blurMax: [0-9]+$' "$view"; then
    warn "LockView.qml has no blurMax to patch — upstream changed; edit ${view/#$HOME/\~} by hand"
    return 1
  fi
  sed -i -E \
    -e "s/^([[:space:]]*blurMax: )[0-9]+\$/\1$LOCK_BLUR_MAX/" \
    -e '/^[[:space:]]*(blurMultiplier|contrast): /d' "$view"
  ok "blurMax = $LOCK_BLUR_MAX"
  # The lock service deliberately survives plugin hot-reloads, so only a shell
  # restart picks up the new view.
  LOCK_NEEDS_RESTART=1
}

# ---- steam: sane UI scale + tiled main window -------------------------

configure_steam() {
  step "Configuring Steam window (UI scale + tiled main window)"
  local hypr_dir="$HOME/.config/hypr"
  local steam_lua="$hypr_dir/steam.lua"
  local hyprland_lua="$hypr_dir/hyprland.lua"
  if [[ ! -d $hypr_dir ]]; then
    skip "No ~/.config/hypr (not a Hyprland/Omarchy setup?)"
    return 0
  fi

  # Managed override, loaded after Omarchy's defaults. Omarchy floats the main
  # Steam window small (1100x700) and lets Steam auto-inflate its UI scale on a
  # HiDPI panel; this pins the scale and tiles the main window. Overwriting is
  # safe — the whole file is ours.
  cat > "$steam_lua" <<'LUA'
-- Managed by omarchy-setup. Loaded after Omarchy's defaults, overriding the
-- stock Steam rules in /usr/share/omarchy/default/hypr/apps/steam.lua.

-- Pin Steam's desktop UI scale. 1 = 100% (right for a 1080p monitor). Bump to
-- "1.25"/"1.5" if it feels too small on a HiDPI laptop panel. Some Steam builds
-- ignore this env var; the same knob lives in Steam > Settings > Accessibility.
hl.env("STEAM_FORCE_DESKTOPUI_SCALING", "1")

-- Tile the main Steam window so it fills the workspace instead of a small
-- floating box. Child windows (Friends List, Settings) stay floating.
o.window({ class = "steam", title = "^Steam$" }, { tile = true })
LUA
  ok "Wrote ${steam_lua/#$HOME/\~}"

  # Ensure hyprland.lua loads it (idempotent).
  if grep -qF 'require("hypr.steam")' "$hyprland_lua" 2>/dev/null; then
    skip 'hyprland.lua already loads hypr.steam'
  elif grep -qF 'require("hypr.autostart")' "$hyprland_lua" 2>/dev/null; then
    cp "$hyprland_lua" "$hyprland_lua.bak.$(date +%s)"
    sed -i '/require("hypr.autostart")/a require("hypr.steam")' "$hyprland_lua"
    ok 'Added require("hypr.steam") to hyprland.lua'
  elif [[ -f $hyprland_lua ]]; then
    cp "$hyprland_lua" "$hyprland_lua.bak.$(date +%s)"
    printf '\nrequire("hypr.steam")\n' >> "$hyprland_lua"
    ok 'Appended require("hypr.steam") to hyprland.lua'
  else
    warn "No hyprland.lua found — add require(\"hypr.steam\") yourself"
  fi

  hyprctl reload >/dev/null 2>&1 || true
}

# ---- screensaver mouse-dismiss watcher ---------------------------------

install_screensaver_mouse_watch() {
  step "Installing screensaver mouse-dismiss watcher"
  # Source it from the local clone when run that way, else fetch from the repo
  # (the setup.sh curl one-liner has no sibling files).
  local src="" script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
  [[ -n $script_dir && -f "$script_dir/$WATCH_REL" ]] && src="$script_dir/$WATCH_REL"

  mkdir -p "$(dirname "$WATCH_DEST")"
  if [[ -n $src ]]; then
    cp -f "$src" "$WATCH_DEST"
  elif ! curl -fsSL "$SETUP_RAW_BASE/$WATCH_REL" -o "$WATCH_DEST"; then
    warn "Could not fetch the screensaver mouse watcher"; return 1
  fi
  chmod 755 "$WATCH_DEST"
  ok "${WATCH_DEST/#$HOME/\~}"

  # Autostart it once per Hyprland session. Absolute path so it resolves
  # regardless of the compositor's PATH.
  local autostart="$HOME/.config/hypr/autostart.lua"
  if [[ -f $autostart ]] && grep -qF 'omarchy-screensaver-mouse-watch' "$autostart"; then
    skip "autostart.lua already launches the watcher"
  else
    mkdir -p "$(dirname "$autostart")"
    [[ -f $autostart ]] && cp "$autostart" "$autostart.bak.$(date +%s)"
    printf '\n-- Added by omarchy-setup: end the screensaver on any mouse movement.\no.launch_on_start("%s")\n' \
      "$WATCH_DEST" >> "$autostart"
    ok "Added watcher to autostart.lua"
  fi

  # Start it now so it works this session without a Hyprland restart. Anchor the
  # match on the script name so pgrep can't match its own command line.
  if pgrep -f 'omarchy-screensaver-mouse-watch$' >/dev/null 2>&1; then
    skip "Watcher already running"
  else
    setsid nohup "$WATCH_DEST" >/dev/null 2>&1 < /dev/null &
    disown 2>/dev/null || true
    ok "Started watcher for this session"
  fi
}

# ---- run ------------------------------------------------------------------

main() {
  require_omarchy
  printf '%s Omarchy setup for keegan-sucks %s\n' "$c_blue" "$c_off"
  install_wallpapers
  install_prune_hook
  install_theme_overlays
  set_bar_opaque
  set_idle_timeouts
  install_roulette
  install_plugins
  configure_lock_screen
  setup_browser
  configure_steam
  install_screensaver_mouse_watch
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  step "Done"
  if [[ -n ${LOCK_NEEDS_RESTART:-} ]]; then
    printf '%sRestart the shell to apply the new lock screen:%s omarchy restart shell\n' "$c_dim" "$c_off"
  else
    printf '%sReload the bar if widgets are not visible:%s omarchy restart shell\n' "$c_dim" "$c_off"
  fi
  printf '%sNotes:%s AirPods needs its own one-time setup (see the plugin README).\n' "$c_dim" "$c_off"
  printf '%s       %s Fully restart Steam (%ssteam -shutdown%s) for the new UI scale to apply.\n' "$c_dim" "$c_off" "$c_dim" "$c_off"
}

main "$@"
