#!/usr/bin/env bash
#
# export-player-icons.sh
#
# Exporta los SVG del set de iconos del OSD (Material Symbols / Heroicons)
# a PNG en los tamaños correctos para cada grupo de botones, y los deja en
# images/ocelotl/icons/player.
#
# Requiere: rsvg-convert (mismo tool que usa export.sh en ocelotl-assets)
#   Debian/Ubuntu: sudo apt install librsvg2-bin
#
# Uso:
#   ./export-player-icons.sh
#
# Ajusta SRC_DIR y OUT_DIR si tu estructura no coincide.

set -euo pipefail

# --- Configuración de rutas ------------------------------------------------

# Carpeta donde están los .svg originales (ej: play.svg, pause.svg, ff.svg...)
SRC_DIR="${SRC_DIR:-./icons-src}"

# Carpeta destino dentro del proyecto Roku
OUT_DIR="${OUT_DIR:-./player}"

# Color de relleno (los SVG de Material Symbols/Heroicons no traen fill
# explícito, heredan negro por default -> forzamos blanco para que se vea
# sobre el fondo oscuro del OSD)
ICON_FILL="#FFFFFF"

# --- Tabla de íconos y tamaño final en px (divisible entre 3, ver fase de --
# --- diseño: play/pause 60, navegación 42, laterales con label 36) --------

declare -A ICON_SIZES=(
  [play]=60
  [pause]=60
  [previous]=42
  [next]=42
  [rewind]=42
  [fw]=42
  [fast-forward]=42
  [ff]=42
  [info]=36
  [options]=36
  [favorite]=36
  [favorite-filled]=36
  [audio-subs]=36
)

# --- Validaciones ------------------------------------------------------------

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "Error: rsvg-convert no está instalado. Instálalo con: sudo apt install librsvg2-bin" >&2
  exit 1
fi

if [ ! -d "$SRC_DIR" ]; then
  echo "Error: no encuentro la carpeta de SVGs source: $SRC_DIR" >&2
  echo "Define SRC_DIR=/ruta/a/tus/svgs antes de correr el script, ej:" >&2
  echo "  SRC_DIR=~/Descargas/player-icons ./export-player-icons.sh" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Origen:  $SRC_DIR"
echo "Destino: $OUT_DIR"
echo ""

# --- Export loop -------------------------------------------------------------

exported=0
skipped=0

for name in "${!ICON_SIZES[@]}"; do
  size="${ICON_SIZES[$name]}"
  src_svg="$SRC_DIR/${name}.svg"
  out_png="$OUT_DIR/${name}.png"

  if [ ! -f "$src_svg" ]; then
    echo "  [saltado] no existe $src_svg"
    skipped=$((skipped + 1))
    continue
  fi

  # Copia temporal con fill forzado a blanco. Los SVG de Material Symbols
  # suelen traer fill="currentColor" (o ninguno) directo en cada <path>, y
  # un fill puesto en el elemento hijo le gana al de la raíz. Por eso:
  #   1) reemplazamos cualquier fill="..." o fill:... existente por blanco
  #   2) inyectamos un <style> de respaldo por si algún path no trae fill
  tmp_svg="$TMP_DIR/${name}.svg"
  sed -E \
    -e "s/fill=\"[^\"]*\"/fill=\"${ICON_FILL}\"/g" \
    -e "s/fill:[^;\"]*/fill:${ICON_FILL}/g" \
    -e "0,/<svg[^>]*>/s//&<style>path,circle,rect,polygon,ellipse,line{fill:${ICON_FILL} !important}<\/style>/" \
    "$src_svg" > "$tmp_svg"

  rsvg-convert \
    --width="$size" \
    --height="$size" \
    --keep-aspect-ratio \
    --format=png \
    --output="$out_png" \
    "$tmp_svg"

  echo "  [ok] ${name}.svg -> ${name}.png (${size}x${size})"
  exported=$((exported + 1))
done

echo ""
echo "Listo: $exported exportados, $skipped saltados."
