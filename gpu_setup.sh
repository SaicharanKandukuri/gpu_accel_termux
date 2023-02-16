#                                                                    
# █▀▀ █▀█ █░█     ▄▀█ █▀▀ █▀▀ █▀▀ █░   ░ ▄▀ █░█ █▀ █ █▄░█ █▀▀    ▀█ █ █▄░█ █▄▀ ▀▄
# █▄█ █▀▀ █▄█     █▀█ █▄▄ █▄▄ ██▄ █▄▄    ▀▄ █▄█ ▄█ █ █░▀█ █▄█    █▄ █ █░▀█ █░█ ▄▀
#
# AUTOMATED BY Thundersnow, ThatMG393
# PATCHES MADE BY Thundersnow

set -e
clear

# Possible values can only be 'enable', 'fix', and 'disable'
# Putting another values will just disable xf86bigfont
USE_XF86BF="fix"

# Yoink from UDroid
DIE() { echo -e "${@}"; exit 1 ;:; }
GWARN() { echo -e "\e[90m${*}\e[0m";:; }
WARN() { echo -e "[WARN]: ${*}\e[0m";:; }

INFO() { echo ""; echo -e "\e[32m${*}\e[0m";:; }
nw_INFO() { echo -e "\e[32m${*}\e[0m";:; }

N_INFO() { echo ""; echo -n -e "\e[32m${*}\e[0m";:; }
Nnw_INFO() { echo -n -e "\e[32m${*}\e[0m";:; }

TITLE() { echo -e "\e[100m${*}\e[0m";:; }

SIG_HANDLER() {
	clear
	DIE "Immediately cancelling as the user requested..."
}

trap 'SIG_HANDLER' SIGKILL SIGINT

if [ -d "/usr" ]; then DIE "Building inside a proot is not supported!"; fi

DEPENDENCIES="vulkaninfo"

INFO "Checking for '$DEPENDENCIES'..."
for DEPENDENCY in $DEPENDENCIES; do
	if [[ ! -n $(command -v $DEPENDENCY) || $( $DEPENDENCY |& grep "(No such file or directory|Command not found)" | wc -l ) == 1 ]]; then
		INFO "Downloading '$DEPENDENCY'..."
		pkg install $DEPENDENCY -y &> /dev/null && INFO "Success!" || DIE "Failed!"
	else
		INFO "'$DEPENDENCY' already installed!"
	fi
done

# Utils
RM_SILENT() { rm -rf "${*}" &> /dev/null ;:; }

echo ""
TITLE " █▀▀ █▀█ █░█     ▄▀█ █▀▀ █▀▀ █▀▀ █░   ░ ▄▀ █░█ █▀ █ █▄░█ █▀▀    ▀█ █ █▄░█ █▄▀ ▀▄  "
TITLE " █▄█ █▀▀ █▄█     █▀█ █▄▄ █▄▄ ██▄ █▄▄    ▀▄ █▄█ ▄█ █ █░▀█ █▄█    █▄ █ █░▀█ █░█ ▄▀  "
echo ""
GWARN "Activating GPU Acceleration (via Zink)"

INFO "Checking for requirements..."

#GPU_VULKAN_SUPPORT=$( getprop | grep "ro.hardware.vulkan" | grep -Po "\[[a-z]*\]" )
#echo -n "Is $GPU_VULKAN_SUPPORT supported?"
# if [[ "$GPU_VULKAN_SUPPORT" = "[mali]" || "$GPU_VULKAN_SUPPORT" = "[qualcomm]" || "$GPU_VULKAN_SUPPORT" = "[powervr]" ]]; then
#	echo " yes"
#else
#	echo " no"
#	exit 1
#fi

GPU_REQ_FEATURES=$( vulkaninfo | grep -oE '(VK_KHR_maintenance1|VK_KHR_create_renderpass2|VK_KHR_imageless_framebuffer|VK_KHR_descriptor_update_template|VK_KHR_timeline_semaphore|VK_EXT_transform_feedback)' | wc -l )

N_INFO "Does GPU has feature VK_KHR_maintenance1, VK_KHR_create_renderpass2, VK_KHR_imageless_framebuffer, VK_KHR_descriptor_update_template, VK_KHR_timeline_semaphore, and VK_EXT_transform_feedback?"
if [[ $GPU_REQ_FEATURES == 6 ]]; then
	echo " yes"
elif [[ $GPU_REQ_FEATURES == 5 ]]; then
	echo ""
	INFO "Wait for another script that installs the old supported version..."
	exit 1
else
	echo " no"
	
	DIE "Double check using 'vulkaninfo | grep VK_KHR'"
	exit 1
fi

GPU_DRIVER_VERSION=$( vulkaninfo | grep driverVersion | cut -d ' ' -f7 | tr -d '.' )

#FIXME: Add Qualcomm Version compare logic
N_INFO "Is the GPU driver version greater than or equal to '38.1.0'? "
if [ $GPU_DRIVER_VERSION -ge 3810 ]; then
	echo " yes"
	
	DIE "GPU driver version >= 38.1.0 is unsupported!"
	exit 1
else
	echo " no"
fi

INFO "You passed the requirements, congrats! Prepare for automatic install. Please keep Termux in focus and don't close Termux..."

#### MAIN LOGIC ####

echo "Y" | termux-setup-storage &> /dev/null

MAIN_FOLDER="$HOME/gpu_accel"
mkdir -p $MAIN_FOLDER

TMP_FOLDER="$MAIN_FOLDER/tmp"

MESA_PATCH_FILE="$MAIN_FOLDER/mesa20230212.patch"
XSERVER_PATCH_FILE="$MAIN_FOLDER/xserver.patch"
VIRGL_DIFF_FILE="$MAIN_FOLDER/virglrenderer.diff"

PATCHES_TAR_GZ="$MAIN_FOLDER/patches.tar.gz"

INFO "Checking for patches and diff files..."

[[ ! -f $MESA_PATCH_FILE || ! -f $XSERVER_PATCH_FILE || ! -f $VIRGL_DIFF_FILE ]] && {
	INFO "Fetching & Extracting 'patches.tar.gz'"
	RM_SILENT $MESA_PATCH_FILE $XSERVER_PATCH_FILE $VIRGL_DIFF_FILE &> /dev/null
	
	cd $MAIN_FOLDER
	# [ $( gzip -t $PATCHES_TAR_GZ && $? ) != 0 ] && {
	[ ! -f $PATCHES_TAR_GZ ] && {
		RM_SILENT $PATCHES_TAR_GZ &> /dev/null # Sanity check
		wget https://raw.githubusercontent.com/ThatMG393/gpu_accel_termux/master/patches.tar.gz &> /dev/null && {
			nw_INFO "Success! (1/2)"
		} || {
			DIE "Failed to fetch 'patches.tar.gz'. Is 'wget' installed? Try doing 'yes | pkg up -y && pkg in wget -y'"
		}
	}
	
	tar -xf $PATCHES_TAR_GZ &> /dev/null && {
		nw_INFO "\33[2K\rSuccess! (2/2)"
	} || {
		DIE "Failed to extract 'patches.tar.gz'. Is 'wget' and 'tar' installed? Try re-running the script."
	}
} || {
	nw_INFO "All found!"
}

echo ""
GWARN "Auto compile & install is starting in 4s, interrupt (Ctrl-C) now if ran accidentally"

sleep 4
clear

TITLE "AUTO INSTALLATION STARTED"

pkg install -y x11-repo -y
pkg install -y clang lld binutils cmake autoconf automake libtool '*ndk*' make python git libandroid-shmem-static 'vulkan*' ninja llvm bison flex libx11 xorgproto libdrm libpixman libxfixes libjpeg-turbo xtrans libxxf86vm xorg-xrandr xorg-font-util xorg-util-macros libxfont2 libxkbfile libpciaccess xcb-util-renderutil xcb-util-image xcb-util-keysyms xcb-util-wm xorg-xkbcomp xkeyboard-config libxdamage libxinerama -y
pip install meson mako

[ -d $TMP_FOLDER ] && {
	INFO "The repositories folder already exists do you want to re-clone the repositories? (y|n)"
	
	read -p "" ANSWER
	
	case $ANSWER in
		y | Y | yes ) RM_SILENT $TMP_FOLDER ;;
		n | N | no  ) INFO "Skipping..." ;;
	esac
}

mkdir -p $TMP_FOLDER
cd $TMP_FOLDER

LD_PRELOAD='' git clone --depth 1 https://gitlab.freedesktop.org/mesa/mesa.git
LD_PRELOAD='' git clone --depth 1 https://gitlab.freedesktop.org/virgl/virglrenderer.git

LD_PRELOAD='' git clone --depth 1 -b libxshmfence-1.3 https://gitlab.freedesktop.org/xorg/lib/libxshmfence.git
LD_PRELOAD='' git clone --depth 1 -b 1.5.10 https://github.com/anholt/libepoxy.git
LD_PRELOAD='' git clone --depth 1 -b 1.21.0 https://gitlab.freedesktop.org/wayland/wayland.git
LD_PRELOAD='' git clone --depth 1 -b 1.26 https://gitlab.freedesktop.org/wayland/wayland-protocols.git
LD_PRELOAD='' git clone --depth 1 -b 0.3 https://github.com/dottedmag/libsha1.git
LD_PRELOAD='' git clone --depth 1 -b xorg-server-1.20.14 https://gitlab.freedesktop.org/xorg/xserver.git

#compile libxshmfence
clear
TITLE "Compiling libxshmfence... (1/8)"
echo ""

cd $TMP_FOLDER/libxshmfence
sed -i s/values.h/limits.h/ ./src/xshmfence_futex.h

RM_SILENT $PREFIX/lib/libxshmfence*

./autogen.sh --prefix=$PREFIX --with-shared-memory-dir=$TMPDIR
make -s -j8 install CPPFLAGS=-DMAXINT=INT_MAX

#compile mesa
clear
TITLE "Compiling & Patching mesa... (2/8)"
echo ""

cd $TMP_FOLDER/mesa
[ ! -f $MESA_PATCH_FILE ] && {
	DIE "Mesa patch file not found! Try re-running the script..."
}
git apply $MESA_PATCH_FILE

mkdir b
cd b

LDFLAGS='-l:libandroid-shmem.a -llog' meson .. -Dprefix=$PREFIX -Dplatforms=x11 -Dgbm=enabled -Dgallium-drivers=zink,swrast -Dllvm=enabled -Dvulkan-drivers='' -Dcpp_rtti=false -Dc_args=-Wno-error=incompatible-function-pointer-types -Dbuildtype=release

RM_SILENT $PREFIX/lib/libglapi.so*
RM_SILENT $PREFIX/lib/libGL.so*
RM_SILENT $PREFIX/lib/libGLES*
RM_SILENT $PREFIX/lib/libEGL*
RM_SILENT $PREFIX/lib/libgbm*

ninja install -d stats

#compile libepoxy
clear
TITLE "Compiling libepoxy... (3/8)"
echo ""

cd $TMP_FOLDER/libepoxy

mkdir b
cd b

meson -Dprefix=$PREFIX -Dbuildtype=release -Dglx=yes -Degl=yes -Dtests=false -Dc_args=-U__ANDROID__ ..

RM_SILENT $PREFIX/lib/libepoxy*

ninja install -d stats

#compile virglrenderer
clear
TITLE "Compiling & Patching virglrenderer... (4/8)"
echo ""

cd $TMP_FOLDER/virglrenderer

[ ! -f $VIRGL_PATCH_FILE ] && {
	DIE "VirGL diff file not found! Try re-running the script..."
}
# git checkout -f master
git apply $VIRGL_DIFF_FILE

mkdir b
cd b

RM_SILENT $PREFIX/lib/libvirglrenderer*

ninja install -d stats

#compile wayland
clear
TITLE "Compiling wayland... (5/8)"
echo ""

RM_SILENT $PREFIX/lib/libwayland*

cd $TMP_FOLDER/wayland

mkdir b
cd b

meson -Dprefix=$PREFIX -Dtests=false -Ddocumentation=false -Dbuildtype=release ..
ninja install -d stats

#compile wayland-protocols
clear
TITLE "Compiling wayland-protocols... (6/8)"
echo ""

RM_SILENT /data/data/com.termux/files/usr/lib/pkgconfig/wayland-protocols.pc

cd $TMP_FOLDER/wayland-protocols

mkdir b
cd b

meson -Dprefix=$PREFIX -Dtests=false -Dbuildtype=release ..
ninja install -d stats

#compile libsha1
clear
TITLE "Compiling libsha1... (7/8)"
echo ""

cd $TMP_FOLDER/libsha1

RM_SILENT $PREFIX/lib/libsha1*

./autogen.sh --prefix=$PREFIX
make -s -j8 install

#compile Xwayland
clear
TITLE "Compiling & Patching xserver... (8/8)"
echo ""

cd $TMP_FOLDER/xserver
[ ! -f $XSERVER_PATCH_FILE ] && {
	DIE "xserver patch file not found! Try re-running the script..."
}
git apply $XSERVER_PATCH_FILE

[[ "$USE_XF86BF" = "enable" || "$USE_XF86BF" = "fix" ]] && {
	./autogen.sh --enable-mitshm --enable-xcsecurity --enable-xf86bigfont --enable-xwayland --enable-xorg --enable-xnest --enable-xvfb --disable-xwin --enable-xephyr --enable-kdrive --disable-devel-docs --disable-config-hal --disable-config-udev --disable-unit-tests --disable-selective-werror --disable-static --without-dtrace --disable-glamor --enable-glx --with-sha1=libsha1 --with-pic --prefix=$PREFIX
} || {
	./autogen.sh --enable-mitshm --enable-xcsecurity --disable-xf86bigfont --enable-xwayland --enable-xorg --enable-xnest --enable-xvfb --disable-xwin --enable-xephyr --enable-kdrive --disable-devel-docs --disable-config-hal --disable-config-udev --disable-unit-tests --disable-selective-werror --disable-static --without-dtrace --disable-glamor --enable-glx --with-sha1=libsha1 --with-pic --prefix=$PREFIX
}

[ "$USE_XF86BF" = "fix" ] && {
	make -s -j8 install LDFLAGS='-fuse-ld=lld /data/data/com.termux/files/usr/lib/libandroid-shmem.a -llog' CPPFLAGS=-DSHMLBA=4096 # CHANGE THIS IF CRASHING OR SMTH
} || {
	make -s -j8 install LDFLAGS='-fuse-ld=lld /data/data/com.termux/files/usr/lib/libandroid-shmem.a -llog'
}

clear
TITLE "DONE!"
INFO "Build success!"

INFO "Termux-X11 is recommended when using this!"

INFO "Script signing off..."
exit 0
