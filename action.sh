#!/system/bin/sh
MODDIR=${0%/*}
[ -f "$MODDIR/config" ] && . "$MODDIR/config"
echo "============================="
echo " Spoof Root Temporary"
echo "============================="
echo " Perfil elegido: ${FPS:-ninguno}"
echo " Modelo actual:  $(getprop ro.product.model)"
echo " Fabricante:     $(getprop ro.product.manufacturer)"
echo "============================="
echo " Cambia los FPS desde el WebUI."
echo " By @LeanHijosdesusMadres"
echo " Channel: @modulostk"
