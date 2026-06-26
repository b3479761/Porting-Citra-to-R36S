#!/bin/bash

# PortMaster preamble
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi
source $controlfolder/control.txt 
export PORT_32BIT="N"
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

# Runtimes and system path variables
weston_dir=/tmp/weston
weston_runtime="weston_pkg_0.2"

mesa_dir=/tmp/mesapack
mesa_runtime="mesapack_pkg_0.1"

azahar_dir=/tmp/Azahar

# Verify/Download Weston Runtime
if [ ! -f "$controlfolder/libs/${weston_runtime}.squashfs" ]; then
    if [ ! -f "$controlfolder/harbourmaster" ]; then
        pm_message "This port requires the latest PortMaster to run, please go to https://portmaster.games for more info."
        sleep 5
        exit 1
    fi
    $ESUDO $controlfolder/harbourmaster --quiet --no-check runtime_check "${weston_runtime}.squashfs"
fi

# Verify/Download Mesapack Runtime for LLVMpipe software emulation
if [ ! -f "$controlfolder/libs/${mesa_runtime}.squashfs" ]; then
    $ESUDO $controlfolder/harbourmaster --quiet --no-check runtime_check "${mesa_runtime}.squashfs"
fi

# Mount Weston runtime image
$ESUDO mkdir -p "${weston_dir}"
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    $ESUDO umount "${weston_dir}" 2>/dev/null
fi
$ESUDO mount "$controlfolder/libs/${weston_runtime}.squashfs" "${weston_dir}"

# Mount Mesapack runtime image
$ESUDO mkdir -p "${mesa_dir}"
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    $ESUDO umount "${mesa_dir}" 2>/dev/null
fi
$ESUDO mount "$controlfolder/libs/${mesa_runtime}.squashfs" "${mesa_dir}"

# Mount Azahar Application Engine 
$ESUDO mkdir -p "${azahar_dir}"
if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    $ESUDO umount "${azahar_dir}" 2>/dev/null
fi
$ESUDO mount /roms/ports/caves3ds/Azahar.squashfs "${azahar_dir}"

# Set up software rendering parameters 
export GALLIUM_HUD="fps,cpu"
export GALLIUM_DRIVER=llvmpipe
export LIBGL_ALWAYS_SOFTWARE=1

# 8. Prepend Mesapack libraries only
# FIXED: Removed the old glxgears binary directory path reference
export LD_LIBRARY_PATH="${mesa_dir}/lib:${mesa_dir}/usr/lib:${mesa_dir}/usr/lib/dri"

# Target the keymapper directly to AppRun so controls hook into the Citra window loop
$GPTOKEYB "AppRun" -c "/roms/ports/caves3ds/netsurf.gptk" & 
sleep 0.5

# Launch the graphical wrapper tool forcing software parameters and the target ROM
$ESUDO env GALLIUM_HUD="$GALLIUM_HUD" GALLIUM_DRIVER=llvmpipe LIBGL_ALWAYS_SOFTWARE=1 LD_LIBRARY_PATH="$LD_LIBRARY_PATH" $weston_dir/westonwrap.sh drm gl kiosk system "${azahar_dir}/AppDir/AppRun" /roms/ports/caves3ds/caves.3ds

# 12. Mandatory cleanup blocks triggered instantly upon hotkey termination (Select+Start)
$ESUDO pkill -9 gptokeyb
$ESUDO pkill -9 weston
$ESUDO pkill -9 westonwrap.sh
$ESUDO pkill -9 AppRun
$ESUDO pkill -9 citra-qt
$ESUDO pkill -9 citra

if [[ "$PM_CAN_MOUNT" != "N" ]]; then
    $ESUDO umount "${weston_dir}"
    $ESUDO umount "${mesa_dir}"
    $ESUDO umount "${azahar_dir}"
fi

# Clear out environmental parameters and temp config files
rm -f /tmp/azahar_keys.cfg
unset LD_LIBRARY_PATH
unset vblank_mode
unset GALLIUM_HUD
unset GALLIUM_DRIVER
unset LIBGL_ALWAYS_SOFTWARE
