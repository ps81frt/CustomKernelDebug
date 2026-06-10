# Custom Kernel DEBUG testé sur Resolute Raccon 26.04 -- OK
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

# ajouter le nom de version voulù ici -cyber-debug

  * EXTRAVERSION =-cyber-debug

    
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


