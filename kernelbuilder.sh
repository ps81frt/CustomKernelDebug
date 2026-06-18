#!/bin/bash
set -euo pipefail

INFO()  { echo -e "\e[32m[INFO]\e[0m  $*"; }
WARN()  { echo -e "\e[33m[WARN]\e[0m  $*"; }
ERROR() { echo -e "\e[31m[ERROR]\e[0m $*" >&2; }
FAIL()  { ERROR "$*"; exit 1; }


KERNEL_VERSION="6.x.y"   # <-- CHANGE ICI LA VERSION (ex: 6.10.5)
THREADS=$(nproc)
DEBUG=false              # true = active les options debug kernel

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
            libssl-dev libelf-dev dwarves wget gnupg2 xz-utils
        ;;
    fedora)
        sudo dnf install -y gcc make ncurses-devel bison flex \
            openssl-devel elfutils-libelf-devel dwarves wget gnupg2 xz
        ;;
    arch)
        sudo pacman -S --needed base-devel ncurses bison flex \
            openssl libelf pahole wget gnupg xz
        ;;
    opensuse)
        sudo zypper install -y gcc make ncurses-devel bison flex \
            libopenssl-devel libelf-devel dwarves wget gpg2 xz
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

./scripts/config --set-str LOCALVERSION "-cyber-debug"

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
    ./scripts/config -d SYSTEM_TRUSTED_KEYS
    ./scripts/config -d SYSTEM_REVOCATION_KEYS

    make olddefconfig
    INFO "Options debug appliquées"
fi

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
