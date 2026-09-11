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
FLOWSTATE_REPO="https://github.com/keegan-sucks/omarchy-flowstate"

# Community plugins: "repo-url|id|label"
PLUGINS=(
  "https://github.com/thisisgm/omarchy-pods|io.github.thisisgm.omapods|AirPods (omapods)"
  "https://github.com/keegan-sucks/rss-feeder|io.github.keegan-sucks.rss-feeder|RSS-Feeder"
  "https://github.com/ierror/menuvitals|io.github.ierror.menuvitals|MenuVitals"
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

# ---- 3. flowstate ---------------------------------------------------------

install_flowstate() {
  step "Installing Flowstate"
  add_plugin "$FLOWSTATE_REPO" "io.github.keegan-sucks.flowstate" "Flowstate"
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

# ---- 5-7. community plugins ----------------------------------------------

install_community_plugins() {
  step "Installing AirPods, RSS-Feeder, and MenuVitals plugins"
  local entry url id label
  for entry in "${PLUGINS[@]}"; do
    IFS='|' read -r url id label <<<"$entry"
    add_plugin "$url" "$id" "$label"
  done
}

# ---- run ------------------------------------------------------------------

main() {
  require_omarchy
  printf '%s Omarchy setup for keegan-sucks %s\n' "$c_blue" "$c_off"
  install_wallpapers
  install_prune_hook
  install_roulette
  install_flowstate
  setup_browser
  install_community_plugins
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  step "Done"
  printf '%sReload the bar if widgets are not visible:%s omarchy restart shell\n' "$c_dim" "$c_off"
  printf '%sNotes:%s AirPods needs its own one-time setup (see the plugin README).\n' "$c_dim" "$c_off"
}

main "$@"
