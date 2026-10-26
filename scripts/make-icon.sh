#!/bin/zsh
# icon/icon.svg -> icon/AppIcon.icns (needs rsvg-convert: brew install librsvg)
set -euo pipefail
cd "${0:A:h:h}/icon"
rm -rf AppIcon.iconset && mkdir AppIcon.iconset
for s in 16 32 128 256 512; do
  rsvg-convert -w $s -h $s icon.svg -o AppIcon.iconset/icon_${s}x${s}.png
  rsvg-convert -w $((s*2)) -h $((s*2)) icon.svg -o AppIcon.iconset/icon_${s}x${s}@2x.png
done
iconutil -c icns AppIcon.iconset -o AppIcon.icns && rm -rf AppIcon.iconset
