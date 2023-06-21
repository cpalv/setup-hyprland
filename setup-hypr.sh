set -e

[ $EUID -ne 0 ] && echo "admin access required for install" && exit 1

dnf install -y xorg-x11-server-Xwayland xorg-x11-server-Xwayland-devel libxcb-devel xorg-x11-util-macros xcb-proto libdrm-devel libinput-devel wlroots-devel cairo-devel pango-devel wayland-protocols-devel doxygen systemd-devel automake autoconf cmake ninja-build git meson g++


# Create Hyprland script
printf "LD_LIBRARY_PATH=/usr/local/lib exec Hyprland -c $HOME/.config/hypr/hyprland.conf" | tee -a /usr/bin/hypr.sh
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

# Download meson-0.59.3 to build hyprland since the latest version in repos
# will not build Hyprland due to warnings that have been bumped to errors
curl -L https://github.com/mesonbuild/meson/releases/download/0.59.3/meson-0.59.3.tar.gz | tar xzf -

# Download and install Hyprland v0.21.0beta
git clone --recurse-submodules https://github.com/hyprwm/Hyprland.git
cd Hyprland
git reset --hard --recurse-submodules $(git rev-list -n 1 v0.21.0beta)
sed -i "s:dependency('gl', 'opengl'),:dependency('gl'),\n    dependency('opengl'),:" src/meson.build
sed -i "s:Exec=Hyprland:Exec=/usr/bin/hypr.sh:" example/hyprland.desktop
mkdir -p /usr/local/share/hyprland-protocols/protocols
cp subprojects/hyprland-protocols/protocols/hyprland-toplevel-export-v1.xml /usr/local/share/hyprland-protocols/protocols/
make clear
make protocols
../meson-0.59.3/meson.py setup --pkg-config-path=/usr/local/lib/pkgconfig _build
ninja -C _build install

echo "Log out of your current desktop environment and try running Hyprland"
echo "Or run manually /usr/bin/hypr.sh"
cat /usr/bin/hypr.sh
