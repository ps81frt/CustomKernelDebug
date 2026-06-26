#!/bin/bash
set -euo pipefail

INFO()  { echo -e "\e[32m[INFO]\e[0m  $*"; }
WARN()  { echo -e "\e[33m[WARN]\e[0m  $*"; }
ERROR() { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }
FAIL()  { ERROR "$*"; exit 1; }


KERNEL_VERSION="6.x.y"   # <-- CHANGE ICI LA VERSION (ex: 6.10.5)
LOCALVERSION="-cyber-debug"
THREADS=$(nproc)
DEBUG=false              # true = active les options debug kernel
PKG_MODE=false           # true = génère deb/rpm au lieu de make install


if [[ "$KERNEL_VERSION" == "6.x.y" ]]; then
    FAIL "modifie KERNEL_VERSION avant de lancer le script !"
fi

MAJOR=$(echo "$KERNEL_VERSION" | cut -d. -f1)

if [ -f /etc/debian_version ]; then
    DISTRO="debian"
elif [ -f /etc/fedora-release ]; then
    DISTRO="fedora"
elif [ -f /etc/arch-release ]; then
    DISTRO="arch"
elif [ -f /etc/SuSE-release ] || grep -qi opensuse /etc/os-release 2>/dev/null; then
    DISTRO="opensuse"
else
    WARN "Distro non détectée — mode manuel requis pour packages/initramfs/grub"
    DISTRO="unknown"
fi
INFO "Distro détectée : $DISTRO"

INFO "Installation kernel.org $KERNEL_VERSION (v${MAJOR}.x)"

case "$DISTRO" in
    debian)
        sudo apt update
        sudo apt install -y build-essential libncurses-dev bison flex \
            libssl-dev libelf-dev dwarves wget gnupg2 xz-utils \
            bc rsync dpkg-dev libdw-dev
        ;;
    fedora)
        sudo dnf install -y gcc make ncurses-devel bison flex \
            openssl-devel elfutils-libelf-devel dwarves wget gnupg2 xz \
            bc rsync rpm-build elfutils-devel python3-devel perl
        ;;
    arch)
        sudo pacman -S --needed base-devel ncurses bison flex \
            openssl libelf pahole wget gnupg xz bc rsync
        ;;
    opensuse)
        sudo zypper install -y gcc make ncurses-devel bison flex \
            libopenssl-devel libelf-devel dwarves wget gpg2 xz \
            bc rsync rpm-build
        ;;
    *)
        WARN "Installation des dépendances ignorée — distro inconnue"
        ;;
esac

BUILD_DIR="$HOME/kernel-build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

TARBALL="linux-$KERNEL_VERSION.tar.xz"
SIGN="linux-$KERNEL_VERSION.tar.sign"
BASE_URL="https://cdn.kernel.org/pub/linux/kernel/v${MAJOR}.x"

INFO "Téléchargement $TARBALL"
wget -c "$BASE_URL/$TARBALL"
wget -c "$BASE_URL/$SIGN"

INFO "Vérification GPG"
gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org 2>/dev/null \
    || WARN "Import clés kernel.org échoué — vérification peut être incomplète"
xz -cd "$TARBALL" | gpg2 --verify "$SIGN" - || \
    FAIL "Signature GPG invalide — archive corrompue ou falsifiée !"
INFO "GPG OK"

INFO "Extraction"
tar -xf "$TARBALL"
cd "linux-$KERNEL_VERSION"

INFO "Récupération config actuelle $(uname -r)"
cp "/boot/config-$(uname -r)" .config

INFO "olddefconfig"
make olddefconfig

./scripts/config --set-str LOCALVERSION "$LOCALVERSION"
./scripts/config -d SYSTEM_TRUSTED_KEYS
./scripts/config -d SYSTEM_REVOCATION_KEYS

if $DEBUG; then
    INFO "Options debug kernel activées"

    ./scripts/config -e DEBUG_KERNEL
    ./scripts/config -e DEBUG_INFO
    ./scripts/config -e DEBUG_INFO_DWARF5
    ./scripts/config -e DEBUG_INFO_BTF
    ./scripts/config -e GDB_SCRIPTS
    ./scripts/config -e FRAME_POINTER
    ./scripts/config -e KALLSYMS
    ./scripts/config -e KALLSYMS_ALL
    ./scripts/config -e KALLSYMS_BASE_RELATIVE
    ./scripts/config -e FTRACE
    ./scripts/config -e FUNCTION_TRACER
    ./scripts/config -d DEBUG_INFO_SPLIT

    make olddefconfig
    INFO "Options debug appliquées"
fi

_install_classic() {
    INFO "Compilation kernel ($THREADS threads)"
    make -j"$THREADS"

    INFO "Installation modules"
    sudo make modules_install INSTALL_MOD_STRIP=1

    INFO "Installation kernel"
    sudo make install

    KREL=$(make -s kernelrelease)
    INFO "Kernel release : $KREL"

    INFO "DKMS rebuild"
    sudo dkms autoinstall || WARN "dkms autoinstall a échoué (non bloquant)"

    INFO "initramfs pour $KREL"
    case "$DISTRO" in
        debian)
            sudo update-initramfs -u -k "$KREL"
            ;;
        fedora|opensuse)
            sudo dracut --force "/boot/initramfs-$KREL.img" "$KREL"
            ;;
        arch)
            sudo mkinitcpio -P
            ;;
        *)
            WARN "initramfs ignoré — distro inconnue, à faire manuellement"
            ;;
    esac

    INFO "update-grub"
    case "$DISTRO" in
        debian)
            sudo update-grub
            ;;
        fedora|opensuse)
            sudo grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || \
                sudo update-grub
            ;;
        arch)
            sudo grub-mkconfig -o /boot/grub/grub.cfg
            ;;
        *)
            WARN "grub ignoré — distro inconnue, à faire manuellement"
            ;;
    esac

    echo ""
    INFO "TERMINÉ — kernel $KREL installé"
    $DEBUG && INFO "Mode DEBUG activé"
    INFO "Reboot : sudo reboot"
}

if $PKG_MODE; then
    case "$DISTRO" in
        debian)
            INFO "Compilation + packaging DEB ($THREADS threads)"
            make -j"$THREADS" bindeb-pkg LOCALVERSION="$LOCALVERSION"

            PKG_DIR="$HOME/kernel-build"
            INFO "Paquets générés :"
            ls -lh "$PKG_DIR"/*.deb

            INFO "Installation DEB"
            sudo dpkg -i "$PKG_DIR"/*.deb
            sudo apt-get install -f -y
            ;;
        fedora|opensuse)
            INFO "Compilation + packaging RPM ($THREADS threads)"
            make -j"$THREADS" rpm-pkg LOCALVERSION="$LOCALVERSION"

            RPM_DIR="$HOME/rpmbuild/RPMS/$(uname -m)"
            INFO "Paquets générés :"
            ls -lh "$RPM_DIR"/kernel-*.rpm

            INFO "Installation RPM"
            sudo dnf install -y "$RPM_DIR"/kernel-*.rpm 2>/dev/null || \
                sudo rpm -ivh "$RPM_DIR"/kernel-*.rpm
            ;;
        arch)
            INFO "Compilation + packaging PKG ($THREADS threads)"
            make -j"$THREADS" tar-pkg LOCALVERSION="$LOCALVERSION"
            WARN "Arch : installer le tar.gz manuellement ou adapter en PKGBUILD"
            ;;
        *)
            WARN "PKG_MODE non supporté pour distro inconnue — bascule sur make install"
            _install_classic
            exit 0
            ;;
    esac

    echo ""
    INFO "TERMINÉ — paquets installés via gestionnaire"
    $DEBUG && INFO "Mode DEBUG activé"
    INFO "Reboot : sudo reboot"
else
    _install_classic
fi
