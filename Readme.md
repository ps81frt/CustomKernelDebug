# Custom Kernel DEBUG testé sur Resolute Raccon 26.04 -- OK DEBIAN UBUNTU
```bash
mkdir -p ~/kernel && cd ~/kernel
```
### Ajout deb-src manuel
```bash
sudo vim /etc/apt/sources.list.d/ubuntu.sources
```
### contenu
```bash
Types: deb deb-src
URIs: http://fr.archive.ubuntu.com/ubuntu/
Suites: resolute resolute-updates resolute-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb deb-src
URIs: http://security.ubuntu.com/ubuntu/
Suites: resolute-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
```

### Ajout deb-src auto
```bash
sudo sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
sudo apt update
```
### Récupération des sources du noyaux
```bash
sudo apt source linux-image-unsigned-$(uname -r)
```
## installation
```bash
cd linux-*
sudo cp /boot/config-$(uname -r) .config
```



### Dépendances
```bash
sudo apt update
sudo apt install -y build-essential bc bison flex libssl-dev libelf-dev dwarves libdw-dev rsync dpkg-dev
```
```bash
sudo make clean
```
```bash
## Ajout des options de debug
sudo make localmodconfig

sudo ./scripts/config -e DEBUG_KERNEL
sudo ./scripts/config -e DEBUG_INFO
sudo ./scripts/config -e DEBUG_INFO_DWARF5
sudo ./scripts/config -e DEBUG_INFO_BTF
sudo ./scripts/config -e GDB_SCRIPTS
sudo ./scripts/config -e FRAME_POINTER
sudo ./scripts/config -e KALLSYMS
sudo ./scripts/config -e KALLSYMS_ALL
sudo ./scripts/config -e KALLSYMS_BASE_RELATIVE

sudo ./scripts/config -e FTRACE
sudo ./scripts/config -e FUNCTION_TRACER

sudo ./scripts/config --disable DEBUG_INFO_SPLIT
sudo ./scripts/config --disable SYSTEM_TRUSTED_KEYS
sudo ./scripts/config --disable SYSTEM_REVOCATION_KEYS

sudo make olddefconfig

```

### Compilation et récupération des paramètre du noyau courant avec ajout des options

```bash
sudo make olddefconfig
```
### controle
```bash
sudo grep -E "CONFIG_DEBUG_KERNEL|CONFIG_DEBUG_INFO|CONFIG_GDB_SCRIPTS|CONFIG_FRAME_POINTER|CONFIG_KALLSYMS|CONFIG_KALLSYMS_ALL|CONFIG_FTRACE|CONFIG_FUNCTION_TRACER|DEBUG_INFO_SPLIT|KALLSYMS_BASE_RELATIVE" .config | grep -v "^#"
```
# Changer le nom de version

```bash
sudo vim Makefile
```

### ajouter le nom de version voulù ici -cyber-debug

  * EXTRAVERSION =-cyber-debug
#### ou
```bash
make LOCALVERSION="-cyber-debug"
```
## Finalisation    
```bash
sudo make -j$(nproc) bindeb-pkg
```
```bash
ls -l ~/kernel/*.deb
cd ..
```
### Installation
```bash
sudo dpkg -i *.deb
sudo apt-get install -f
```
# Custom Kernel DEBUG FEDORA 44

# Custom Kernel DEBUG — Fedora (testé sur Fedora 40/41)

```bash
mkdir -p ~/kernel && cd ~/kernel
```

---

## Dépendances

```bash
sudo dnf install -y \
  gcc make bc bison flex \
  openssl-devel elfutils-libelf-devel \
  dwarves elfutils-devel \
  rsync rpm-build ncurses-devel \
  python3-devel perl
```

---

## Récupération des sources du noyau

### Méthode 1 — Via DNF (recommandée)

```bash
# Activer les sources (si pas déjà fait)
sudo dnf install -y 'dnf-command(download)'

# Télécharger les sources du noyau courant
sudo dnf download --source kernel-$(uname -r | sed 's/\.[^.]*$//')
```

```bash
# Installer le SRPM
rpm -ivh kernel-*.src.rpm
cd ~/rpmbuild/SOURCES/
# Les sources sont dans ~/rpmbuild/
```

### Méthode 2 — Via koji (kernel Fedora officiel)

```bash
sudo dnf install -y koji

# Récupérer le SRPM exact correspondant au noyau courant
KVER=$(uname -r | sed 's/\.[^.]*$//')
koji download-build --arch=src kernel-${KVER}
rpm -ivh kernel-*.src.rpm
```

### Méthode 3 — kernel.org (noyau vanilla)

```bash
# Exemple avec 6.9.x — adapter à votre version
KVER=6.9.7
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KVER}.tar.xz
tar xf linux-${KVER}.tar.xz
cd linux-${KVER}
```

---

## Configuration de base

```bash
# Copier la config du noyau courant
cp /boot/config-$(uname -r) .config

# Adapter la config aux modules actuellement chargés
sudo make localmodconfig
```

---

## Ajout des options de debug

```bash
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

./scripts/config --disable DEBUG_INFO_SPLIT
./scripts/config --disable SYSTEM_TRUSTED_KEYS
./scripts/config --disable SYSTEM_REVOCATION_KEYS
```

```bash
# Résoudre les dépendances de config
make olddefconfig
```

### Contrôle

```bash
grep -E "CONFIG_DEBUG_KERNEL|CONFIG_DEBUG_INFO|CONFIG_GDB_SCRIPTS|\
CONFIG_FRAME_POINTER|CONFIG_KALLSYMS|CONFIG_KALLSYMS_ALL|\
CONFIG_FTRACE|CONFIG_FUNCTION_TRACER|\
DEBUG_INFO_SPLIT|KALLSYMS_BASE_RELATIVE" .config | grep -v "^#"
```

---

## Changer le nom de version

### Option A — via Makefile

```bash
vim Makefile
# Modifier la ligne :
#   EXTRAVERSION = -cyber-debug
```

### Option B — à la compilation

```bash
make LOCALVERSION="-cyber-debug" -j$(nproc)
```

---

## Compilation et packaging RPM

```bash
# Compilation complète + génération des RPMs
make -j$(nproc) bindeb-pkg    # ← Ubuntu
# Sur Fedora, utiliser à la place :
make -j$(nproc) rpm-pkg LOCALVERSION="-cyber-debug"
```

Les RPMs sont générés dans `~/rpmbuild/RPMS/x86_64/` :

```bash
ls ~/rpmbuild/RPMS/x86_64/
```

---

## Installation

```bash
cd ~/rpmbuild/RPMS/x86_64/

# Installer kernel + headers (kernel-devel optionnel)
sudo dnf install -y \
  kernel-*.rpm \
  kernel-devel-*.rpm \
  kernel-headers-*.rpm
```

> **Note :** `dnf install` gère les dépendances automatiquement,
> contrairement à `rpm -ivh` qui peut bloquer sur des conflits.

---

## Vérification post-install

```bash
# Lister les noyaux installés
rpm -qa kernel | sort

# Vérifier l'entrée GRUB
sudo grubby --info=ALL | grep -E "title|kernel"

# Forcer le boot sur le nouveau noyau (optionnel)
sudo grubby --set-default /boot/vmlinuz-*cyber-debug*
```

```bash
sudo reboot
# Après reboot :
uname -r   # doit afficher *-cyber-debug
```

---

## Différences clés Ubuntu vs Fedora

| Aspect              | Ubuntu                        | Fedora                        |
|---------------------|-------------------------------|-------------------------------|
| Format package      | `.deb`                        | `.rpm`                        |
| Commande build      | `make bindeb-pkg`             | `make rpm-pkg`                |
| Output dir          | `~/kernel/*.deb`              | `~/rpmbuild/RPMS/x86_64/`    |
| Installation        | `dpkg -i *.deb`               | `dnf install *.rpm`           |
| Sources noyau       | `apt source linux-image-...`  | `dnf download --source kernel-...` |
| Signing keys        | `SYSTEM_TRUSTED_KEYS`         | idem (désactiver pareil)      |
| SELinux             | non (AppArmor)                | **actif** — voir note ci-dessous |

###  SELinux sur Fedora

Si le noyau custom refuse de booter ou génère des AVCs :

```bash
# Vérifier les refus SELinux
sudo ausearch -m avc -ts recent

# Mode permissif temporaire (debug uniquement, pas en prod)
sudo setenforce 0
```

Pour un noyau de debug, vous pouvez aussi ajouter à la ligne kernel dans GRUB :

```
enforcing=0
```

