#!/usr/bin/bash

# Build a docker image of archlinux
# https://github.com/Hoverbear/docker-archlinux
# https://github.com/docker/docker/blob/master/contrib/mkimage-arch.sh

# See docker tty/pty issue on "docker exec"
# https://github.com/docker/docker/issues/8755
# https://github.com/dattlabs/datt-archlinux/blob/master/Dockerfile
# "exec >/dev/tty 2>/dev/tty </dev/tty"


SCRIPT_NAME=$(basename ${0})
SCRIPT_VERSION='1.0.0'

# set font types
FONT_DEFAULT=${FONT_DEFAULT:-"\e[0m"}
FONT_SUCCESS=${FONT_SUCCESS:-"\e[1;32m"}
FONT_INFO=${FONT_INFO:-"\e[1;37m"}
FONT_NOTICE=${FONT_NOTICE:-"\e[1;35m"}
FONT_WARNING=${FONT_WARNING:-"\e[1;33m"}
FONT_ERROR=${FONT_ERROR:-"\e[1;31m"}


# default args
DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME:-'archlinux'}
#DOCKER_IMAGE_TAG=${DOCKER_IMAGE_TAG:-'latest'}
PACMAN_MIRRORLIST_URL=${PACMAN_MIRRORLIST_URL:-'https://www.archlinux.org/mirrorlist/?country=all&protocol=http&protocol=https&ip_version=4&use_mirror_status=on'}
if [[ ! "${IGNORE_PACKAGES_BASE}" ]]; then
    IGNORE_PACKAGES_BASE='cryptsetup,dhcpcd,jfsutils,linux,logrotate,lvm2,man-db,man-pages,mdadm,pciutils,pcmciautils,reiserfsprogs,s-nail,systemd-sysvcompat,usbutils,xfsprogs'
fi
if [[ ! "${REQUIRED_PACKAGES[@]}" ]]; then
    REQUIRED_PACKAGES=("btrfs-progs")
fi
# Additional packages
# uuid


function show_usage() {
    echo -e "${FONT_INFO}Usage: ${SCRIPT_NAME} [OPTIONS]${FONT_DEFAULT}"
    echo
    echo -e "${FONT_INFO}Options:${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ -h, --help ]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ -v, --version ]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ --docker-user-name \${DOCKER_USER_NAME} ]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ --docker-image-name \${DOCKER_IMAGE_NAME} ]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ --docker-image-tag \${DOCKER_IMAGE_TAG} ]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ --archlinux-version \${ARCHLINUX_VERSION} ]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ --base-working-dir \${BASE_WORKING_DIRECTORY} ]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ --pacman-mirrorlist-url \${PACMAN_MIRRORLIST_URL} ]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ --import-image]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ --run-container-test]${FONT_DEFAULT}"
    echo
}


# dependencies
function check_dependencies () {
    hash $1 &>/dev/null || {
            echo -e "${FONT_ERROR}[ERROR] Could not find ${1}${FONT_DEFAULT}" 1>&2
            echo
            exit 1
    }
}


if [[ ${UID} != 0 ]]; then
    echo -e "${FONT_ERROR}[ERROR] Only root user can run ${SCRIPT_NAME}.${FONT_DEFAULT}" 1>&2
    echo
    exit 1
fi


check_dependencies gpg
check_dependencies docker
check_dependencies curl


for OPT in "$@"; do
    case "$OPT" in
    '-h' | '--help' )
        show_usage
        exit 0
        ;;
    '-v' | '--version' )
        echo -e "${FONT_INFO}${SCRIPT_VERSION}${FONT_DEFAULT}"
        exit 0
        ;;
    '--docker-user-name' )
        if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
            echo -e "${FONT_ERROR}[ERROR] ${SCRIPT_NAME}: option requires an argument -- ${1}${FONT_DEFAULT}" 1>&2
            echo
            show_usage
            exit 1
        fi
        DOCKER_USER_NAME=$2
        shift 2
        ;;
    '--docker-image-name' )
        if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
            echo -e "${FONT_ERROR}[ERROR] ${SCRIPT_NAME}: option requires an argument -- ${1}${FONT_DEFAULT}" 1>&2
            echo
            show_usage
            exit 1
        fi
        DOCKER_IMAGE_NAME=$2
        shift 2
        ;;
    '--docker-image-tag' )
        if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
            echo -e "${FONT_ERROR}[ERROR] ${SCRIPT_NAME}: option requires an argument -- ${1}${FONT_DEFAULT}" 1>&2
            echo
            show_usage
            exit 1
        fi
        DOCKER_IMAGE_TAG=$2
        shift 2
        ;;
    '--archlinux-version' )
        if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
            echo -e "${FONT_ERROR}[ERROR] ${SCRIPT_NAME}: option requires an argument -- ${1}${FONT_DEFAULT}" 1>&2
            echo
            show_usage
            exit 1
        fi
        ARCHLINUX_VERSION=$2
        shift 2
        ;;
    '--base-working-dir' )
        if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
            echo -e "${FONT_ERROR}[ERROR] ${SCRIPT_NAME}: option requires an argument -- ${1}${FONT_DEFAULT}" 1>&2
            echo
            show_usage
            exit 1
        fi
        BASE_WORKING_DIRECTORY=$2
        shift 2
        ;;
    '--pacman-mirrorlist-url' )
        if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
            echo -e "${FONT_ERROR}[ERROR] ${SCRIPT_NAME}: option requires an argument -- ${1}${FONT_DEFAULT}" 1>&2
            echo
            show_usage
            exit 1
        fi
        PACMAN_MIRRORLIST_URL=$2
        shift 2
        ;;
    '--import-image' )
        IMPORT_IMAGE='true'
        shift
        ;;
    '--run-container-test' )
        RUN_CONTAINER_TEST='true'
        shift
        ;;
    -*)
        echo -e "${FONT_ERROR}[ERROR] ${SCRIPT_NAME}: invalid option -- $(echo ${1} | sed 's/^-*//')'${FONT_DEFAULT}" 1>&2
        echo
        show_usage
        exit 1
        ;;
    *)
    if [[ ! -z "${1}" ]] && [[ ! "${1}" =~ ^-+ ]]; then
        #param=( ${param[@]} "${1}" )
        param+=( "${1}" )
        shift
    fi
    ;;
  esac
done


# Start
echo -e "${FONT_INFO}[INFO] Started ${SCRIPT_NAME}${FONT_DEFAULT}"
trap "
if [[ \"${CHROOT_DIR}\" ]]; then
    for _pid in $(lsof -nlP 2>/dev/null | grep \"${CHROOT_DIR}\" | awk '{ print $2 }' | uniq); do
        kill ${_pid} || true
    done
    sleep 3
    umount --recursive ${CHROOT_DIR} || umount --force --recursive ${CHROOT_DIR} || umount --lazy --recursive ${CHROOT_DIR} || true
fi
echo -e \"${FONT_ERROR}[ERROR] Exitted with error${FONT_DEFAULT}\" 1>&2
echo" ERR


set -e


if [[ ! "${DOCKER_USER_NAME}" ]]; then
    echo -e "${FONT_ERROR}[ERROR] No docker id specified${FONT_DEFAULT}" 1>&2
    echo
    show_usage
    exit 1
fi


if [[ ! "${ARCHLINUX_VERSION}" ]]; then
    #ARCHLINUX_VERSION=$(curl https://mirrors.kernel.org/archlinux/iso/latest/ | grep -Poh '(?<=archlinux-bootstrap-)\d*\.\d*\.\d*(?=\-x86_64)' | head -n 1)
    ARCHLINUX_VERSION=$(curl --fail --silent --location https://mirrors.kernel.org/archlinux/iso/latest/ | egrep -o "href=\"archlinux-bootstrap-[0-9]{4}\.[0-9]{1,2}\.[0-9]{1,2}-x86_64.tar.gz\"" | head -n 1 | egrep -o "[0-9]{4}\.[0-9]{1,2}\.[0-9]{1,2}") || (echo -e "${FONT_ERROR}[ERROR] Could not get latest version of archlinux${FONT_DEFAULT}" 1>&2; exit 1)
fi


BASE_WORKING_DIRECTORY=$(dirname ${BASE_WORKING_DIRECTORY:-${TMPDIR:-/tmp}}/x)
WORKING_DIRECTORY=$(mktemp -d ${BASE_WORKING_DIRECTORY}/.build.docker-image.archlinux-${ARCHLINUX_VERSION}-x86_64.XXXXXXXXXX)


if [[ "${IMPORT_IMAGE}" ]]; then
    IMPORT_IMAGE='true'
else
    IMPORT_IMAGE='false'
fi


if [[ "${RUN_CONTAINER_TEST}" ]]; then
    RUN_CONTAINER_TEST='true'
else
    RUN_CONTAINER_TEST='false'
fi


echo
echo -e "${FONT_NOTICE}Building archlinux docker image ...${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --docker-user-name: ${DOCKER_USER_NAME}${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --docker-image-name: ${DOCKER_IMAGE_NAME}${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --docker-image-tag: ${DOCKER_IMAGE_TAG}${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --archlinux-version: ${ARCHLINUX_VERSION}${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --base-working-dir: ${BASE_WORKING_DIRECTORY}${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --pacman-mirrorlist-url: ${PACMAN_MIRRORLIST_URL}${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --import-image: ${IMPORT_IMAGE}${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --run-container-test: ${RUN_CONTAINER_TEST}${FONT_DEFAULT}"
echo

cd ${WORKING_DIRECTORY}


###
# Get the Archlinux bootstrap image
###
echo -e "${FONT_INFO}[INFO] Getting archlinux-bootstrap-${ARCHLINUX_VERSION}-x86_64 ...${FONT_DEFAULT}"
curl --fail --silent --location "https://mirrors.kernel.org/archlinux/iso/${ARCHLINUX_VERSION}/archlinux-bootstrap-${ARCHLINUX_VERSION}-x86_64.tar.gz" > archlinux-bootstrap-${ARCHLINUX_VERSION}-x86_64.tar.gz || (echo -e "${FONT_ERROR}[ERROR] Could not get latest version of archlinux${FONT_DEFAULT}" 1>&2; exit 1)
curl --fail --silent --location "https://mirrors.kernel.org/archlinux/iso/${ARCHLINUX_VERSION}/archlinux-bootstrap-${ARCHLINUX_VERSION}-x86_64.tar.gz.sig" > archlinux-bootstrap-${ARCHLINUX_VERSION}-x86_64.tar.gz.sig || (echo -e "${FONT_ERROR}[ERROR] Could not get latest version signature of archlinux${FONT_DEFAULT}" 1>&2; exit 1)
echo -e "${FONT_SUCCESS}[SUCCESS] Got archlinux-bootstrap-${ARCHLINUX_VERSION}-x86_64${FONT_DEFAULT}"


# Pull Pierre Schmitz PGP Key.
# http://pgp.mit.edu:11371/pks/lookup?op=vindex&fingerprint=on&exact=on&search=0x4AA4767BBC9C4B1D18AE28B77F2D434B9741E8AC
echo -e "${FONT_INFO}[INFO] Verifing archlinux-bootstrap-${ARCHLINUX_VERSION}-x86_64.tar.gz ...${FONT_DEFAULT}"
gpg --keyserver pgp.mit.edu --recv-keys 9741E8AC


# Verify its integrity.
gpg --verify archlinux-bootstrap-${ARCHLINUX_VERSION}-x86_64.tar.gz.sig || (echo -n "${FONT_ERROR}[ERROR] Failed to verify archlinux-bootstrap-${ARCHLINUX_VERSION}-x86_64.tar.gz${FONT_DEFAULT}" 1>&2; exit 1)
echo -e "${FONT_SUCCESS}[SUCCESS] Verified archlinux-bootstrap-${ARCHLINUX_VERSION}-x86_64.tar.gz${FONT_DEFAULT}"


# Extract
tar xf archlinux-bootstrap-${ARCHLINUX_VERSION}-x86_64.tar.gz > /dev/null


###
# Do necessary install steps.
###
CHROOT_DIR="${WORKING_DIRECTORY}/root.x86_64"


# Get pacman mirrorlist
echo -e "${FONT_INFO}[INFO] Getting pacman mirrorlist${FONT_DEFAULT}"
rm -f ${CHROOT_DIR}/etc/pacman.d/mirrorlist
curl --fail --silent --location "${PACMAN_MIRRORLIST_URL}" -o ${CHROOT_DIR}/etc/pacman.d/mirrorlist || (echo "${FONT_ERROR}[ERROR] Could not get latest pacman mirrorlist${FONT_DEFAULT}" 1>&2; exit 1)
sed --in-place -e 's/^#Server/Server/g' ${CHROOT_DIR}/etc/pacman.d/mirrorlist
echo -e "${FONT_SUCCESS}[SUCCESS] Got pacman mirrorlist${FONT_DEFAULT}"


echo -e "${FONT_INFO}[INFO] Modifying files${FONT_DEFAULT}"
# /etc/pacman.conf
start_line_num=$(egrep -n -m 1 '^#\[multilib\]\s*$' ${CHROOT_DIR}/etc/pacman.conf | cut -d ':' -f 1)
if [ "${start_line_num}" ]; then
    line_count=$(sed -n "${start_line_num},$(($start_line_num + 100))p" ${CHROOT_DIR}/etc/pacman.conf | egrep -n -m 1 '^\s*$' | cut -d ':' -f 1)
    if [ "${line_count}" ]; then
        sed --in-place -e "${start_line_num}i # ${DOCKER_USER_NAME}\/${DOCKER_IMAGE_NAME} >>>" ${CHROOT_DIR}/etc/pacman.conf
        sed --in-place -e "$((${start_line_num} + 1)),$((${start_line_num} + ${line_count}))s/^#\(.\+\)/\1/g" ${CHROOT_DIR}/etc/pacman.conf
        sed --in-place -e "$((${start_line_num} + ${line_count}))i # ${DOCKER_USER_NAME}\/${DOCKER_IMAGE_NAME} <<<" ${CHROOT_DIR}/etc/pacman.conf
    fi
fi
cat <<-HEND >> ${CHROOT_DIR}/etc/pacman.conf

# ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} >>>
[archlinuxfr]
SigLevel = Never
Server = http://repo.archlinux.fr/\$arch
# ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} <<<
HEND


# /etc/locale.gen
sed --in-place -e 's/^#\(en_US.UTF-8 UTF-8.*\)/\1/g' ${CHROOT_DIR}/etc/locale.gen
sed --in-place -e 's/^#\(en_US ISO-8859-1.*\)/\1/g' ${CHROOT_DIR}/etc/locale.gen
sed --in-place -e 's/^#\(ja_JP.UTF-8 UTF-8.*\)/\1/g' ${CHROOT_DIR}/etc/locale.gen


# /etc/localtime
ln -sf /usr/share/zoneinfo/UTC ${CHROOT_DIR}/etc/localtime


# /etc/bash.bashrc
cat <<-HEND >> ${CHROOT_DIR}/etc/bash.bashrc

# ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} >>>
unset HISTFILE
export HISTFILESIZE=0
export HISTSIZE=500
export HISTCONTROL=ignoreboth
# ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} <<<
HEND


# /etc/bash.bash_logout
cat <<-HEND >> ${CHROOT_DIR}/etc/bash.bash_logout

# ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} >>>
rm -f ~/.pip/pip.log
rm -f ~/.*_history
rm -f ~/.*hist
clear
history -c && history -w
# ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} <<<
HEND


# /etc/skel/.bashrc
#cat <<-HEND >> ${CHROOT_DIR}/etc/skel/.bashrc
#
## ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} >>>
#alias vi >/dev/null 2>&1 || alias vi='vim'
## ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} <<<
#HEND


# /etc/skel/.bash_profile
cat <<-HEND >>  ${CHROOT_DIR}/etc/skel/.bash_profile

# ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} >>>
[[ -f ~/.profile ]] && . ~/.profile
# ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} <<<
HEND


# /etc/skel/.lesskey /etc/skel/.less
cat <<-'HEND' > ${CHROOT_DIR}/etc/skel/.lesskey
#env
LESSHISTFILE=-
LESSHISTSIZE=0
HEND
lesskey -o ${CHROOT_DIR}/etc/skel/.less ${CHROOT_DIR}/etc/skel/.lesskey
chmod 644 ${CHROOT_DIR}/etc/skel/.less*


# /root/.bash* /root/.profile* /root/.less*
cp -apr ${CHROOT_DIR}/etc/skel/.bash* ${CHROOT_DIR}/root/. >/dev/null 2>&1
cp -apr ${CHROOT_DIR}/etc/skel/.profile* ${CHROOT_DIR}/root/. >/dev/null 2>&1|| true
cp -apr ${CHROOT_DIR}/etc/skel/.less* ${CHROOT_DIR}/root/.


# /etc/profile.d/umask.sh
cat <<-HEND > ${CHROOT_DIR}/etc/profile.d/umask.sh
# ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} >>>
# By default, we want umask to get set. This sets it for login shell
# Current threshold for system reserved uid/gids is 200
# You could check uidgid reservation validity in
# /usr/share/doc/setup-*/uidgid file
if [ \$UID -gt 199 ] && [ "\`id -gn\`" = "\`id -un\`" ]; then
    umask 002
else
    umask 022
fi
# ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} <<<
HEND
chmod +x ${CHROOT_DIR}/etc/profile.d/umask.sh


#mkdir -p ${CHROOT_DIR}/etc/sudoers.d
#cat <<-'HEND' > ${CHROOT_DIR}/etc/sudoers.d/pacman
#nobody ALL=(ALL) NOPASSWD: /usr/bin/pacman
#HEND
#chmod 440 ${CHROOT_DIR}/etc/sudoers.d/pacman


#cat <<-'HEND' > ${CHROOT_DIR}/root/yaourtrc
#custom_mpkg () {
#  chown -R nobody .
#  sudo -u nobody makepkg "$@"
#}
#MAKEPKG=custom_mpkg
#HEND
#chmod 600 ${CHROOT_DIR}/root/yaourtrc


# /etc/systemd/journald.conf.d/99-default.conf
mkdir -p ${CHROOT_DIR}/etc/systemd/journald.conf.d
chmod 755 ${CHROOT_DIR}/etc/systemd/journald.conf.d
cat <<-'HEND' > ${CHROOT_DIR}/etc/systemd/journald.conf.d/99-default.conf
SystemMaxUse=64M
RuntimeMaxUse=16M
HEND
chmod 644 ${CHROOT_DIR}/etc/systemd/journald.conf.d/99-default.conf


# /opt/local/bin/x-set-shell-fonts-env.sh
mkdir -p ${CHROOT_DIR}/opt/local/bin
cat <<-'HEND' > ${CHROOT_DIR}/opt/local/bin/x-set-shell-fonts-env.sh
#!/bin/bash

FONT_DEFAULT="\e[0m"
FONT_SUCCESS="\e[1;32m"
FONT_INFO="\e[1;37m"
FONT_NOTICE="\e[1;35m"
FONT_WARNING="\e[1;33m"
FONT_ERROR="\e[1;31m"
HEND
chmod +x ${CHROOT_DIR}/opt/local/bin/x-set-shell-fonts-env.sh


# /usr/lib/systemd/system/multi-user.target.wants/systemd-logind.service
#rm -f ${CHROOT_DIR}/usr/lib/systemd/system/multi-user.target.wants/systemd-logind.service
#ln -sf /dev/null ${CHROOT_DIR}/etc/systemd/system/systemd-logind.service

# /usr/lib/systemd/system/sysinit.target.wants/systemd-firstboot.service
#rm -f ${CHROOT_DIR}/usr/lib/systemd/system/sysinit.target.wants/systemd-firstboot.service
#ln -sf /dev/null ${CHROOT_DIR}/etc/systemd/system/systemd-firstboot.service

# /usr/lib/systemd/system/x-pacman-keyring.service
cat <<-'HEND' > ${CHROOT_DIR}/usr/lib/systemd/system/x-pacman-keyring.service
[Unit]
Description=Refresh pacman keyring

[Service]
Type=oneshot
ExecStart=/usr/bin/pacman-key --refresh-keys
HEND
chmod 644 ${CHROOT_DIR}/usr/lib/systemd/system/x-pacman-keyring.service


# /usr/lib/systemd/system/x-pacman-keyring.timer
cat <<-'HEND' > ${CHROOT_DIR}/usr/lib/systemd/system/x-pacman-keyring.timer
[Unit]
Description=Refresh pacman keyring once a month
Documentation=man:pacman-key

[Timer]
OnCalendar=monthly
AccuracySec=1h
Persistent=true

[Install]
WantedBy=multi-user.target
HEND
chmod 644 ${CHROOT_DIR}/usr/lib/systemd/system/x-pacman-keyring.timer
ln -sf ../x-pacman-keyring.timer ${CHROOT_DIR}/usr/lib/systemd/system/multi-user.target.wants/x-pacman-keyring.timer

# /opt/local/bin/x-archlinux-remove-unnecessary-files.sh
cat <<-'HEND' > ${CHROOT_DIR}/opt/local/bin/x-archlinux-remove-unnecessary-files.sh
#!/bin/bash

set -e

source /opt/local/bin/x-set-shell-fonts-env.sh
echo -e "${FONT_INFO}[INFO] Removing unnecessary files${FONT_DEFAULT}"
_pkg_orphans=$(sudo -u nobody yaourt -Qtdq || true)
if [[ ! -z "${_pkg_orphans}" ]];then
    echo -e "${FONT_WARNING}[WARNING] ######## Orphan packages #######\n${_pkg_orphans}${FONT_DEFAULT}"
fi
_pkg_file_updates=$(find / -type f -regextype posix-extended -regex ".+\.pac(new|save|orig)" || true)
if [[ ! -z "${_pkg_file_updates}" ]];then
    echo -e "${FONT_WARNING}[WARNING] ######## Files updated by pacman #######\n${_pkg_file_updates}${FONT_DEFAULT}"
fi
paccache --remove --uninstalled --keep 0 >/dev/null 2>&1 || true
paccache --remove --keep 0 >/dev/null 2>&1 || true
#pacman -Scc --noconfirm
#rm -rf /var/cache/pacman/pkg/*
rm -f /etc/pacman.d/mirrorlist.pacnew
rm -f /var/log/pacman.log
rm -f ~/.pip/pip.log
rm -f ~/.*_history
rm -f ~/.*hist
find /tmp -mindepth 1 -delete || true
find /var/tmp -mindepth 1 -delete || true
history -c && history -w
echo -e "${FONT_SUCCESS}[SUCCESS] Removed unnecessary files${FONT_DEFAULT}"
HEND
chmod 744 ${CHROOT_DIR}/opt/local/bin/x-archlinux-remove-unnecessary-files.sh


echo -e "${FONT_SUCCESS}[SUCCESS] Modified files${FONT_DEFAULT}"


echo
echo -e "${FONT_NOTICE}#################### pgp entropy ####################${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}To get enough entropy, do one of the following methods:${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  1. Use rngd${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  2. Use haveged${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  3. dd if=/dev/urandom of=/dev/null bs=1M count=2048${FONT_DEFAULT}"
echo

./root.x86_64/bin/arch-chroot ${CHROOT_DIR} /usr/bin/bash <<- HEND
unset TMPDIR
set -e

echo -e "${FONT_INFO}[INFO] Initializing pacman key${FONT_DEFAULT}"
rm -rf /etc/pacman.d/gnupg
pacman-key --init
pacman-key --populate archlinux
echo -e "${FONT_SUCCESS}[SUCCESS] Initialized pacman key${FONT_DEFAULT}"

echo -e "${FONT_INFO}[INFO] Updating package database and installed packages${FONT_DEFAULT}"
pacman -Syyu --noconfirm --noprogressbar
echo -e "${FONT_SUCCESS}[SUCCESS] Updated package database and installed packages${FONT_DEFAULT}"

echo -e "${FONT_INFO}[INFO] Installing [sudo expect]${FONT_DEFAULT}"
pacman -S --needed --noconfirm --noprogressbar sudo expect
echo -e "${FONT_SUCCESS}[SUCCESS] Installed [sudo expect]${FONT_DEFAULT}"

cat <<-'HEND0' > /etc/sudoers.d/wheel
%wheel ALL=(ALL) NOPASSWD: ALL
HEND0
chmod 440 /etc/sudoers.d/wheel

cat <<-'HEND0' > /etc/sudoers.d/pacman
nobody ALL=(ALL) NOPASSWD: /usr/bin/pacman
HEND0
chmod 440 /etc/sudoers.d/pacman

#echo -e "${FONT_INFO}[INFO] Installing [gcc-multilib libtool-multilib]${FONT_DEFAULT}"
#expect <<- HEND0
#    set send_slow {1 0.3}
#    set timeout -1
#    spawn pacman -S --needed --noprogressbar gcc-multilib libtool-multilib
#    expect {
#        -exact " is in IgnorePkg/IgnoreGroup. Install anyway? \[Y/n\] " { sleep 0.3; send "n\r"; exp_continue }
#        -exact "Remove gcc-libs? \[y/N\] " { sleep 0.3; send -- "y\r"; exp_continue }
#        -exact "Remove libtool? \[y/N\] " { sleep 0.3; send -- "y\r"; exp_continue }
#        -exact "Proceed with installation? \[Y/n\]" { sleep 0.3; send -- "y\r"; exp_continue }
#        eof { exit 0 }
#    }
#HEND0
#echo -e "${FONT_SUCCESS}[SUCCESS] Installed [gcc-multilib libtool-multilib]${FONT_DEFAULT}"

echo -e "${FONT_INFO}[INFO] Installing [base/base-devel]${FONT_DEFAULT}"
expect <<- HEND0
    set IGNORE_PACKAGES_BASE $env(IGNORE_PACKAGES_BASE)
    set send_slow {1 0.3}
    set timeout -1
    spawn pacman -S --needed --noprogressbar base base-devel --ignore $IGNORE_PACKAGES_BASE
    expect {
        -exact " is in IgnorePkg/IgnoreGroup. Install anyway? \[Y/n\] " { sleep 0.3; send -- "n\r"; exp_continue }
        -exact "Enter a selection (default=all): " { sleep 0.3; send -- "\r"; exp_continue }
        -exact "Proceed with installation? \[Y/n\]" { sleep 0.3; send -- "y\r"; exp_continue }
        eof { exit 0 }
    }
HEND0

[[ ! -d /root/.gnupg ]] && mkdir /root/.gnupg
chmod 700 /root/.gnupg
gpg --list-keys && echo -e "\n\n# ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} >>>\nkeyserver-options auto-key-retrieve\n# ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME} <<<" >> /root/.gnupg/gpg.conf
chmod 600 /root/.gnupg/gpg.conf
echo -e "${FONT_SUCCESS}[SUCCESS] Installed [base/base-devel]${FONT_DEFAULT}"

echo -e "${FONT_INFO}[INFO] Installing [reflector]${FONT_DEFAULT}"
pacman -S --needed --noconfirm  --noprogressbar reflector
reflector --latest 100 --verbose --sort score --save /etc/pacman.d/mirrorlist
pacman -Syyu --noconfirm --noprogressbar
#sed -e 's/OPT_LONG=(\(.\+\)/OPT_LONG=('asroot' \1/g' /bin/makepkg | sed -e 's/\(exit 1 # \$E_USER_ABORT\)/#\1/g' > /usr/local/bin/makepkg
#chmod 755 /usr/local/bin/makepkg
echo -e "${FONT_SUCCESS}[SUCCESS] Installed [reflector]${FONT_DEFAULT}"

echo -e "${FONT_INFO}[INFO] Installing [yaourt]${FONT_DEFAULT}"
pacman -S --needed --noconfirm --noprogressbar yaourt
sed --in-place -e "s/^\(#TMPDIR=.*\)/\1\n# ${DOCKER_USER_NAME}\/${DOCKER_IMAGE_NAME} >>>\nTMPDIR=\"\/var\/tmp\"\n# ${DOCKER_USER_NAME}\/${DOCKER_IMAGE_NAME} <<</g" /etc/yaourtrc
echo -e "${FONT_SUCCESS}[SUCCESS] Installed [yaourt]${FONT_DEFAULT}"

if [[ "${REQUIRED_PACKAGES[@]}" ]]; then
    echo -e "${FONT_INFO}[INFO] Installing [${REQUIRED_PACKAGES[@]}]${FONT_DEFAULT}"
    sudo -u nobody yaourt -S --needed --noconfirm --noprogressbar "${REQUIRED_PACKAGES[@]}"
    echo -e "${FONT_SUCCESS}[SUCCESS] Installed [${REQUIRED_PACKAGES[@]}]${FONT_DEFAULT}"
fi

echo -e "${FONT_INFO}[INFO] Modifying locale${FONT_DEFAULT}"
locale-gen

#locale > /etc/locale.conf
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
echo -e "${FONT_SUCCESS}[SUCCESS] Modified locale${FONT_DEFAULT}"

pkill gpg-agent

/opt/local/bin/x-archlinux-remove-unnecessary-files.sh
# pacman-optimize
HEND

if [[ $? -ne 0 ]];then
    exit 1
fi


# /etc/makepkg.conf
#sed --in-place -e "s/^\(CFLAGS=\".\+\)/# ${DOCKER_USER_NAME}\/${DOCKER_IMAGE_NAME} #\1\nCFLAGS=\"-march=native -O2 -pipe -fstack-protector-strong --param=ssp-buffer-size=4 -D_FORTIFY_SOURCE=2\"\nCXXFLAGS=\${CFLAGS}/g" ${CHROOT_DIR}/etc/makepkg.conf
#sed --in-place -e "s/^\(CXXFLAGS=\".\+\)/# ${DOCKER_USER_NAME}\/${DOCKER_IMAGE_NAME} #\1/g" ${CHROOT_DIR}/etc/makepkg.conf
#sed --in-place -e "s/^\(CFLAGS=\".\+\)/# ${DOCKER_USER_NAME}\/${DOCKER_IMAGE_NAME} #\1\nCFLAGS=\"-march=native -O2 -pipe -fstack-protector-strong\"\nCXXFLAGS=\${CFLAGS}/g" ${CHROOT_DIR}/etc/makepkg.conf
#sed --in-place -e "s/^\(CXXFLAGS=\".\+\)/# ${DOCKER_USER_NAME}\/${DOCKER_IMAGE_NAME} #\1/g" ${CHROOT_DIR}/etc/makepkg.conf


# /etc/login.defs
sed --in-place -e "s/^\(UID_MIN\s\+1000\s*\)$/# ${DOCKER_USER_NAME}\/${DOCKER_IMAGE_NAME} #\1\nUID_MIN\t\t\t50000/g" ${CHROOT_DIR}/etc/login.defs
sed --in-place -e "s/^\(UID_MAX\s\+60000\s*\)$/# ${DOCKER_USER_NAME}\/${DOCKER_IMAGE_NAME} #\1\nUID_MAX\t\t\t59999/g" ${CHROOT_DIR}/etc/login.defs
sed --in-place -e "s/^\(GID_MIN\s\+1000\s*\)$/# ${DOCKER_USER_NAME}\/${DOCKER_IMAGE_NAME} #\1\nGID_MIN\t\t\t50000/g" ${CHROOT_DIR}/etc/login.defs
sed --in-place -e "s/^\(GID_MAX\s\+60000\s*\)$/# ${DOCKER_USER_NAME}\/${DOCKER_IMAGE_NAME} #\1\nGID_MAX\t\t\t59999/g" ${CHROOT_DIR}/etc/login.defs


# /etc/pam.d/su
sed --in-place -e "s/^#\(auth\s\+required\s\+pam_wheel.so use_uid\s*\)/# ${DOCKER_USER_NAME}\/${DOCKER_IMAGE_NAME} #\1\n\1/g" ${CHROOT_DIR}/etc/pam.d/su


# /etc/nsswitch.conf
# http://lukeluo.blogspot.jp/2015/04/the-best-way-to-configure-network.html
# https://github.com/systemd/systemd/blob/master/README#L214
NSS_HOSTS_LINE=$(egrep '^hosts.+' ${CHROOT_DIR}/etc/nsswitch.conf || true)
if [[ -z "${NSS_HOSTS_LINE}" ]]; then
    echo -e "\n# ${CONF_TAG} >>>\nhosts: files myhostname mymachines resolve dns\n# ${CONF_TAG} <<<" >> ${CHROOT_DIR}/etc/nsswitch.conf
else
    NEW_NSS_HOSTS_LINE="${NSS_HOSTS_LINE}"
    if $(echo "${NEW_NSS_HOSTS_LINE}" | egrep -q 'dns'); then
        echo "${NEW_NSS_HOSTS_LINE}" | egrep -q 'myhostname' || DNS_SOURCES='myhostname'
        echo "${NEW_NSS_HOSTS_LINE}" | egrep -q 'mymachines' || DNS_SOURCES="${DNS_SOURCES:+${DNS_SOURCES} }mymachines"
        echo "${NEW_NSS_HOSTS_LINE}" | egrep -q 'resolve' || DNS_SOURCES="${DNS_SOURCES:+${DNS_SOURCES} }resolve"
        if [[ "${DNS_SOURCES}" ]]; then
            NEW_NSS_HOSTS_LINE=$(echo "${NEW_NSS_HOSTS_LINE}" | sed -e "s/dns/${DNS_SOURCES} dns/")
        fi
    fi
    if [[ "${NEW_NSS_HOSTS_LINE}" != "${NSS_HOSTS_LINE}" ]]; then
        sed --in-place -e "s/^\(hosts.\+\)/# ${CONF_TAG} #\1\n${NEW_NSS_HOSTS_LINE}/" ${CHROOT_DIR}/etc/nsswitch.conf
    fi
fi
unset NSS_HOSTS_LINE
unset NEW_NSS_HOSTS_LINE
unset DNS_SOURCES


# /etc/systemd/resolved.conf.d/zz-default.conf
mkdir -p ${CHROOT_DIR}/etc/systemd/resolved.conf.d
cat <<-HEND >> ${CHROOT_DIR}/etc/systemd/resolved.conf.d/zz-default.conf
# ${CONF_TAG} >>>
[Resolve]
#DNS=
FallbackDNS=8.8.8.8 8.8.4.4 2001:4860:4860::8888 2001:4860:4860::8844
#LLMNR=yes
# ${CONF_TAG} <<<
HEND


# /etc/machine-id
rm -f ${CHROOT_DIR}/etc/machine-id


sync && sync && sync
sleep 3

for _pid in $(lsof -nlP 2>/dev/null | grep "${CHROOT_DIR}" | awk '{ print $2 }' | uniq); do
    kill ${_pid} || true
done
sleep 3
umount --recursive ${CHROOT_DIR} || umount --force --recursive ${CHROOT_DIR} || umount --lazy --recursive ${CHROOT_DIR} || true


# tmp files
find ${CHROOT_DIR}/tmp -mindepth 1 -delete || true
find ${CHROOT_DIR}/var/tmp -mindepth 1 -delete || true


###
# udev doesnt work in containers, rebuild /dev
# Taken from https://raw.githubusercontent.com/dotcloud/docker/master/contrib/mkimage-arch.sh
###

echo -e "${FONT_INFO}[INFO] Rebuilding /dev${FONT_DEFAULT}"
DEV="${WORKING_DIRECTORY}/root.x86_64/dev"
rm -rf ${DEV}
mkdir -p ${DEV}
mknod -m 666 ${DEV}/null c 1 3
mknod -m 666 ${DEV}/zero c 1 5
mknod -m 666 ${DEV}/random c 1 8
mknod -m 666 ${DEV}/urandom c 1 9
mkdir -m 755 ${DEV}/pts
mkdir -m 1777 ${DEV}/shm
mknod -m 666 ${DEV}/tty c 5 0
mknod -m 600 ${DEV}/console c 5 1
mknod -m 666 ${DEV}/tty0 c 4 0
mknod -m 666 ${DEV}/full c 1 7
mknod -m 600 ${DEV}/initctl p
mknod -m 666 ${DEV}/ptmx c 5 2
ln -sf /proc/self/fd ${DEV}/fd
echo -e "${FONT_SUCCESS}[SUCCESS] Rebuilt /dev${FONT_DEFAULT}"


###
# Build the container., Import it.
###
if [ ${IMPORT_IMAGE} == "true" ]; then
    _DATETIME_TAG=$(date --utc +%Y.%m.%d.%H.%M)
    echo -e "${FONT_INFO}[INFO] Importing docker image ...${FONT_DEFAULT}"
    tar --numeric-owner -C root.x86_64 -c .  | docker import - ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME}:${_DATETIME_TAG}
    cd ${BASE_WORKING_DIRECTORY}
    rm -rf ${WORKING_DIRECTORY}
    echo -e "${FONT_NOTICE}[NOTICE] Removed working directory [${WORKING_DIRECTORY}]${FONT_DEFAULT}"
    echo -e "${FONT_SUCCESS}[SUCCESS] Created an docker image [${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME}:${_DATETIME_TAG}]${FONT_DEFAULT}"

    ###
    # Test run
    ###
    if [ ${RUN_CONTAINER_TEST} == "true" ]; then
        echo -e "${FONT_INFO}[INFO] Starting container ...${FONT_DEFAULT}"
        docker run --rm=true ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME}:${_DATETIME_TAG} echo "echo from the container"
        if [ $? == 0 ]; then
            echo -e "${FONT_SUCCESS}[SUCCESS] Running container test has successfully finished${FONT_DEFAULT}"
        else
            echo -e "${FONT_ERROR}[ERROR] Running container test failed${FONT_DEFAULT}" 1>&2
        fi
    fi

    ###
    # tag
    ###
    if [[ "${DOCKER_IMAGE_TAG}" ]] && [[ "${DOCKER_IMAGE_TAG}" != "${_DATETIME_TAG}" ]]; then
        docker tag ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME}:${_DATETIME_TAG} ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}
        echo -e "${FONT_SUCCESS}[SUCCESS] Tagged ${DOCKER_USER_NAME}/${DOCKER_IMAGE_NAME}:${DOCKER_IMAGE_TAG}${FONT_DEFAULT}"
    fi
fi

echo -e "${FONT_SUCCESS}[SUCCESS] Finished ${SCRIPT_NAME}${FONT_DEFAULT}"
exit 0
