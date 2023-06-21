set -e

[ $EUID -ne 0 ] && echo "admin access required for install" && exit 1

dnf install -y xorg-x11-server-Xwayland xorg-x11-server-Xwayland-devel libxcb-devel xorg-x11-util-macros xcb-proto libdrm-devel libdrm drm-utils wlroots-devel cairo-devel pango-devel wayland-protocols-devel doxygen systemd-devel automake autoconf cmake ninja-build git meson g++ libdisplay-info-devel hwdata-devel libseat libseat-devel

# Create Hyprland script
printf "LD_LIBRARY_PATH=/usr/local/lib exec Hyprland\n" > /usr/bin/hypr.sh
chmod 755 /usr/bin/hypr.sh

# Build libxcb-errors
# Cannot find this package in Fedora repos
# If somebody knows feel free to update
mkdir -p /usr/local/src 
cd /usr/local/src
git clone https://gitlab.freedesktop.org/xorg/lib/libxcb-errors.git
cd libxcb-errors/
git submodule update --init
./autogen.sh
./configure && make install
cd ..

pixmanver=(`dnf info pixman-devel | awk 'NR<10 && /Version/{split($3, arr, "."); print arr[1],arr[2],arr[3]}'`)

# Last time I checked Fedora 37 repos have pixman-devel 0.40.0 and Fedora 38 has 0.42.2
# pixman-devel is already included as dependency in above install
# $ dnf info --releasever ## PACKAGE
if [[ ${pixmanver[1]} -lt 42 && ${pixmanver[2]} -lt 2 ]]; then
	# Download and install pixamn-0.42.2
	git clone git://anongit.freedesktop.org/git/pixman.git
	cd pixman && git checkout pixman-0.42.2 && ./configure && make -j $(nproc) install
	cd ..
fi


# Download and install Hyprland v0.26.0
git clone --recurse-submodules https://github.com/hyprwm/Hyprland.git
cd Hyprland

liftoffver=(`dnf info libliftoff-devel | awk 'NR<10 && /Version/{split($3, arr, "."); print arr[1],arr[2],arr[3]}'`)

# Future proof
if [[ ${liftoffver[1]} -lt 4 && ${liftoffver[2]} -ge 0 ]]; then
	cd subprojects
	git clone https://gitlab.freedesktop.org/emersion/libliftoff.git
	git reset --hard $(git rev-list -n 1 v0.4.1)
	# just incase the directory gets caught in the next reset
	rm -rf .git
	cd ..
else
	dnf install libliftoff-devel
fi

git reset --hard --recurse-submodules $(git rev-list -n 1 v0.26.0)

sed -i "s:Exec=Hyprland:Exec=/usr/bin/hypr.sh:" example/hyprland.desktop
make clear

meson setup --pkg-config-path=/usr/local/lib/pkgconfig _build

ninja -C _build install

USER_HOME=/home/$SUDO_USER
mkdir -p $USER_HOME/.config
cp ./example/hyprland.conf $USER_HOME/.config/
chown -R $SUDO_USER:$SUDO_USER $USER_HOME/.config

echo "Log out of your current desktop environment and try running Hyprland"
echo "Or run manually /usr/bin/hypr.sh"
cat /usr/bin/hypr.sh
