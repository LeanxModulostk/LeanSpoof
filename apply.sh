#!/system/bin/sh
# Uso: apply.sh <id|default>            solo escribe system.prop (y config); id de profiles.conf (CODM),
#                                       freefire.conf (ff...), games.conf / more.conf (mg_...) o apps.conf (app_...)
#      apply.sh soft [segundos]         reinicio suave (el de KernelSU via ksud, o el userspace reboot de Android);
#                                       con segundos, en segundo plano tras ese retraso
#      apply.sh softcheck               imprime el metodo disponible: ksud, userspace o none
#      apply.sh reboot                  reinicio completo del dispositivo
# Salida (ultima linea): OK|<valor>|<estado> o ERR|<motivo>
MODDIR=${0%/*}
ARG="$1"

LOG=/data/local/tmp/codmfps_soft.log
[ -d /data/local/tmp ] && [ -w /data/local/tmp ] || LOG=/dev/null
log() { echo "$(date '+%F %T') $*" >> "$LOG" 2>/dev/null; }

# Se lanza en segundo plano y desacoplado del proceso que nos llamo (instalador o WebUI).
detach() {
  if command -v setsid >/dev/null 2>&1; then
    setsid sh -c "$1" </dev/null >/dev/null 2>&1 &
  else
    sh -c "$1" </dev/null >/dev/null 2>&1 &
  fi
}

# El reinicio suave de Android (userspace reboot) solo funciona si el dispositivo lo declara soportado.
userspace_supported() {
  case "$(getprop init.userspace_reboot.is_supported)" in true|1) return 0 ;; *) return 1 ;; esac
}

# KernelSU: el "Soft reboot" del gestor es un reinicio emulado que gestiona ksud: reinicia los servicios y
# vuelve a ejecutar las etapas de arranque (post-fs-data, service...), donde se cargan los system.prop.
find_ksud() {
  for p in "$(command -v ksud 2>/dev/null)" /data/adb/ksud /data/adb/ksu/bin/ksud; do
    [ -n "$p" ] && [ -x "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

# Imprime el comando de soft reboot de ksud si existe. Se detecta leyendo la ayuda: no se ejecuta nada.
ksud_soft_cmd() {
  KSUD=$(find_ksud) || return 1
  if "$KSUD" --help 2>&1 | grep -q 'soft-reboot'; then echo "$KSUD soft-reboot"; return 0; fi
  if "$KSUD" debug --help 2>&1 | grep -q 'soft-reboot'; then echo "$KSUD debug soft-reboot"; return 0; fi
  return 1
}

soft_method() {
  if ksud_soft_cmd >/dev/null 2>&1; then echo ksud
  elif userspace_supported; then echo userspace
  else echo none
  fi
}

# Pide el reinicio suave y comprueba que arranco (sys.boot_completed se vacia al empezar).
do_soft() {
  log "soft: init.userspace_reboot.is_supported=$(getprop init.userspace_reboot.is_supported)"
  /system/bin/svc power reboot userspace >>"$LOG" 2>&1 || /system/bin/reboot userspace >>"$LOG" 2>&1
  log "soft: comando lanzado (rc=$?)"
  sleep "${SOFT_WAIT:-8}"
  IP=$(getprop sys.init.userspace_reboot.in_progress)
  if [ "$(getprop sys.boot_completed)" != "1" ] || [ "$IP" = "true" ] || [ "$IP" = "1" ]; then
    return 0
  fi
  log "soft: sin efecto (boot_completed=1 y userspace reboot no esta en curso)"
  return 1
}

# Usa el reinicio suave de ksud si existe; si no, el userspace reboot de Android
do_soft_any() {
  CMD=$(ksud_soft_cmd) && {
    log "soft: ksud -> $CMD"
    $CMD >>"$LOG" 2>&1; RC=$?
    log "soft: ksud rc=$RC"
    return $RC
  }
  do_soft
}

case "$ARG" in
  softcheck) soft_method; exit 0 ;;
  soft|soft-now)
    # Reinicio suave: con KernelSU, el de ksud; si no, el userspace reboot de Android.
    # Ambos vuelven a ejecutar las etapas de arranque, donde se cargan los system.prop.
    # soft-now: uso interno (lo llama el modo con retraso).
    if [ "$ARG" = "soft-now" ]; then do_soft_any; exit $?; fi
    if [ "$(soft_method)" = "none" ]; then
      log "soft: no disponible (sin ksud soft-reboot, init.userspace_reboot.is_supported=$(getprop init.userspace_reboot.is_supported))"
      echo "ERR|unsupported"; exit 1
    fi
    case "$2" in
      ''|*[!0-9]*)
        # Desde el WebUI. Con ksud se lanza desacoplado (setsid): al reiniciar, el gestor se cierra y
        # no debe llevarse por delante el proceso del reinicio.
        if [ "$(soft_method)" = "ksud" ]; then
          detach "sleep 1; sh $MODDIR/apply.sh soft-now"
          echo "OK|soft|soft"; exit 0
        fi
        # Con el userspace reboot de Android se ejecuta aqui mismo para poder informar si no tuvo efecto
        if do_soft_any; then echo "OK|soft|soft"; exit 0; fi
        echo "ERR|noeffect"; exit 1 ;;
      *)
        # Desde el instalador: con retraso y en segundo plano
        detach "sleep $2; sh $MODDIR/apply.sh soft-now"
        echo "OK|soft|soft"; exit 0 ;;
    esac ;;
  reboot)
    detach 'sleep 2; reboot || svc power reboot'
    echo "OK|reboot|reboot"; exit 0 ;;
esac

if [ "$ARG" = "default" ]; then
  [ -s "$MODDIR/defaults.conf" ] || { echo "ERR|no hay valores por defecto guardados"; exit 1; }
  MODEL=$(cut -d'|' -f1 "$MODDIR/defaults.conf" | head -n 1)
  MANU=$(cut -d'|' -f2 "$MODDIR/defaults.conf" | head -n 1)
  LABEL="Valores originales del dispositivo"
else
  case "$ARG" in ''|*[!A-Za-z0-9_]*) echo "ERR|valor invalido"; exit 1 ;; esac
  LINE=$(cat "$MODDIR/profiles.conf" "$MODDIR/freefire.conf" "$MODDIR/games.conf" "$MODDIR/apps.conf" "$MODDIR/more.conf" 2>/dev/null | grep "^$ARG|" | head -n 1)
  [ -z "$LINE" ] && { echo "ERR|el perfil $ARG no existe"; exit 1; }
  MODEL=$(echo "$LINE" | cut -d'|' -f2)
  MANU=$(echo "$LINE" | cut -d'|' -f3)
  LABEL="$(echo "$LINE" | cut -d'|' -f4) [$ARG]"
fi

{
  echo "# $LABEL"
  echo "ro.product.model=$MODEL"
  echo "ro.product.manufacturer=$MANU"
} > "$MODDIR/system.prop"
printf 'FPS=%s\n' "$ARG" > "$MODDIR/config"
echo "OK|$ARG|saved"
