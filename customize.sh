# Spoof Root Temporary - @LeanHijosdesusMadres / @modulostk
P="$MODPATH/profiles.conf"

ui_print "*******************************"
ui_print "░█▀▀▀█ █▀▀█ █▀▀█ █▀▀█ █▀▀ "
ui_print "─▀▀▀▄▄ █──█ █──█ █──█ █▀▀ "
ui_print "░█▄▄▄█ █▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀"
ui_print "▒█▀▀█ █▀▀█ █▀▀█ ▀▀█▀▀ "
ui_print "▒█▄▄▀ █░░█ █░░█ ░░█░░ "
ui_print "▒█░▒█ ▀▀▀▀ ▀▀▀▀ ░░▀░░"
ui_print "▀▀█▀▀ █▀▀ █▀▄▀█ █▀▀█ █▀▀█ █▀▀█ █▀▀█ █▀▀█ █──█ "
ui_print "─░█── █▀▀ █─▀─█ █──█ █──█ █▄▄▀ █▄▄█ █▄▄▀ █▄▄█ "
ui_print "─░█── ▀▀▀ ▀───▀ █▀▀▀ ▀▀▀▀ ▀─▀▀ ▀──▀ ▀─▀▀ ▄▄▄█"
ui_print ""
ui_print " By @LeanHijosdesusMadres"
ui_print " Channel: @modulostk"
ui_print "*******************************"

get_key() {
  while :; do
    ev=$(timeout 20 getevent -lqc 1 2>/dev/null)
    [ -z "$ev" ] && { echo none; return; }
    case "$ev" in
      *KEY_VOLUMEUP*DOWN*) echo up; return ;;
      *KEY_VOLUMEDOWN*DOWN*) echo down; return ;;
    esac
  done
}

# Valores originales del dispositivo (para poder restaurarlos despues)
# Modulo anterior con otro id (CODMFPS): se reutilizan sus datos y se marca para eliminar
LEGACY="/data/adb/modules/CODMFPS"
OLDDEF="/data/adb/modules/$MODID/defaults.conf"
[ -s "$OLDDEF" ] || OLDDEF="$LEGACY/defaults.conf"
if [ -s "$OLDDEF" ]; then
  cp "$OLDDEF" "$MODPATH/defaults.conf"
else
  # Si ro.product.* ya esta simulado por un modulo anterior, se usan las variantes vendor/odm/system
  pick() {
    CUR=$(getprop "$1")
    if [ -n "$CUR" ] && ! cat "$P" "$MODPATH/freefire.conf" "$MODPATH/games.conf" "$MODPATH/apps.conf" "$MODPATH/more.conf" 2>/dev/null | grep -qF "|$CUR|"; then echo "$CUR"; return; fi
    shift
    for k in "$@"; do v=$(getprop "$k"); [ -n "$v" ] && { echo "$v"; return; }; done
    echo "$CUR"
  }
  DM=$(pick ro.product.model ro.product.vendor.model ro.product.odm.model ro.product.system.model ro.product.product.model)
  DF=$(pick ro.product.manufacturer ro.product.vendor.manufacturer ro.product.odm.manufacturer ro.product.system.manufacturer ro.product.product.manufacturer)
  echo "$DM|$DF" > "$MODPATH/defaults.conf"
fi
ui_print " Original del dispositivo: $(cut -d'|' -f1 "$MODPATH/defaults.conf") ($(cut -d'|' -f2 "$MODPATH/defaults.conf"))"

# Perfil inicial: al actualizar se conserva el que tenias; si no, los valores originales
INIT=default
OLDCFG="/data/adb/modules/$MODID/config"
[ -f "$OLDCFG" ] || OLDCFG="$LEGACY/config"
if [ -f "$OLDCFG" ]; then
  OLDID=$(sed -n 's/^FPS=//p' "$OLDCFG" | head -n 1)
  [ -n "$OLDID" ] && INIT="$OLDID"
fi
sh "$MODPATH/apply.sh" "$INIT" >/dev/null 2>&1 || { INIT=default; sh "$MODPATH/apply.sh" default >/dev/null 2>&1; }
if [ "$MODID" != CODMFPS ] && [ -d "$LEGACY" ]; then
  touch "$LEGACY/remove"
  ui_print " Modulo anterior (CODMFPS) se eliminara al reiniciar"
fi
if [ "$INIT" = default ]; then
  ui_print " Sin spoof por ahora: elige uno en el WebUI"
else
  ui_print " Se conserva tu perfil anterior"
fi

# Reinicio suave al terminar (solo si esta disponible: ksud de KernelSU o userspace reboot de Android)
# Vol+ = si, Vol- = no; sin respuesta = no
SOFT_M=$(sh "$MODPATH/apply.sh" softcheck 2>/dev/null)
SOFT_OK=0
case "$SOFT_M" in ksud|userspace) SOFT_OK=1 ;; esac

SOFT_NOW=0
if [ "$SOFT_OK" = 1 ]; then
  ui_print "*******************************"
  ui_print " TEMPORARY ROOT USERS "
  ui_print "*******************************"
  ui_print " Aplicar reinicio suave?"
  ui_print " Apply a soft reset?"
  ui_print " Vol+ = Si / Yes    Vol- = No / No"
  [ "$(get_key)" = "up" ] && SOFT_NOW=1
  if [ "$SOFT_NOW" = 1 ]; then ui_print "  > Si / Yes"; else ui_print "  > No"; fi
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/apply.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755

ui_print "*******************************"
if [ "$SOFT_NOW" = 1 ]; then
  R=$(sh "$MODPATH/apply.sh" soft 3 | tail -n 1)
  case "$R" in
    OK*) ui_print " Reinicio suave en 3 segundos..." ;;
    *)   ui_print " No se pudo iniciar el reinicio suave."
         ui_print " Reinicia el dispositivo para activarlo." ;;
  esac
elif [ "$SOFT_OK" = 0 ]; then
  ui_print " Reinicio suave no disponible aqui"
  ui_print " (ni ksud soft-reboot ni userspace reboot)."
  ui_print " Reinicia el dispositivo para activarlo."
else
  ui_print " Reinicia para activarlo."
fi
ui_print " Despues elige el spoof desde el WebUI."
ui_print "*******************************"
