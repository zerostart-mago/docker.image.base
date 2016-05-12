#!/usr/bin/bash

# Install python

SCRIPT_NAME=$(basename ${0})
SCRIPT_VERSION='1.0'


# set font types
FONT_DEFAULT=${FONT_DEFAULT:-"\e[0m"}
FONT_SUCCESS=${FONT_SUCCESS:-"\e[1;32m"}
FONT_INFO=${FONT_INFO:-"\e[1;37m"}
FONT_NOTICE=${FONT_NOTICE:-"\e[1;35m"}
FONT_WARNING=${FONT_WARNING:-"\e[1;33m"}
FONT_ERROR=${FONT_ERROR:-"\e[1;31m"}


# default args
BASE_URL_PYTHON_SOURCE=${BASE_URL_PYTHON_SOURCE:-'https://www.python.org/ftp/python/'}
URL_PYTHON_SOURCE=${URL_PYTHON_SOURCE:-''}
URL_PIP_INSTALLER=${URL_PIP_INSTALLER:-'https://bootstrap.pypa.io/get-pip.py'}


function show_usage() {
    echo -e "${FONT_INFO}Usage: ${SCRIPT_NAME} [OPTIONS]${FONT_DEFAULT}"
    echo
    echo -e "${FONT_INFO}Options:${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ -h, --help ]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ -v, --version ]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  --python-version \${PYTHON_VERSION}${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ --prefix \${PREFIX} ]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ --base-working-dir \${BASE_WORKING_DIRECTORY} ]${FONT_DEFAULT}"
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


check_dependencies porg


for OPT in "$@"; do
    case "$OPT" in
    '-h' | '--help' )
        show_usage
        exit 0
        ;;
    '-v' | '--version' )
        echo -e '${FONT_INFO}${SCRIPT_VERSION}${FONT_DEFAULT}'
        exit 0
        ;;
    '--python-version' )
        if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
            echo -e "${FONT_ERROR}[ERROR] ${SCRIPT_NAME}: option requires an argument -- ${1}${FONT_DEFAULT}" 1>&2
            echo
            show_usage
            exit 1
        fi
        PYTHON_VERSION=$2
        shift 2
        ;;
    '--prefix' )
        if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
            echo -e "${FONT_ERROR}[ERROR] ${SCRIPT_NAME}: option requires an argument -- ${1}${FONT_DEFAULT}" 1>&2
            echo
            show_usage
            exit 1
        fi
        PREFIX=$2
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
trap 'echo -e "${FONT_ERROR}[ERROR] Exitted with error${FONT_DEFAULT}" 1>&2; echo' ERR


set -e


if [[ ! "${PYTHON_VERSION}" ]]; then
	echo -e "${FONT_ERROR}[ERROR] No python version specified${FONT_DEFAULT}" 1>&2
    echo
	show_usage
	exit 1
fi


MAJOR_VERSION=$(echo ${PYTHON_VERSION} | cut -d '.' -f 1)
MINOR_VERSION=$(echo ${PYTHON_VERSION} | cut -d '.' -f 2)
if [[ "${MAJOR_VERSION}" == "3" ]]; then
    REQUIRED_PACKAGES=("libltdl" "zlib" "bzip2" "gettext" "ncurses" "readline" "openssl" "gdbm" "expat" "sqlite" "libffi" "zeromq")
    # REQUIRED_PYTHON_MODULES=("wheel" "ipython[all]")
    REQUIRED_PYTHON_MODULES=("wheel" "ipython" "boto3" "awscli" "pyzmq" "pystache")
elif [[ "${MAJOR_VERSION}" == '2' ]]; then
    REQUIRED_PACKAGES=("libltdl" "zlib" "bzip2" "gettext" "ncurses" "readline" "openssl" "gdbm" "expat" "sqlite" "libffi")
    # REQUIRED_PYTHON_MODULES=("virtualenv" "wheel" "ipython[all]")
    REQUIRED_PYTHON_MODULES=("virtualenv" "wheel" "ipython" "pystache")
else
	echo -e "${FONT_ERROR}[Error] Unknown python version: ${PYTHON_VERSION}${FONT_DEFAULT}" 1>&2
	exit 1
fi


if [ ! ${PREFIX} ]; then
	PREFIX="/opt/local/python-${PYTHON_VERSION}"
fi


BASE_WORKING_DIRECTORY=$(dirname ${BASE_WORKING_DIRECTORY:-${TMPDIR:-/tmp}}/x)
WORKING_DIRECTORY=$(mktemp -d ${BASE_WORKING_DIRECTORY}/.build.python-${PYTHON_VERSION}.XXXXXXXXXX)


echo
echo -e "${FONT_NOTICE}[NOTICE] Building python ...${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --python-version: ${PYTHON_VERSION}${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --prefix: ${PREFIX}${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --base-working-dir: ${WORKING_DIRECTORY}${FONT_DEFAULT}"
echo

cd ${WORKING_DIRECTORY}


if [[ "${REQUIRED_PACKAGES[@]}" ]]; then
    echo -e "${FONT_INFO}[INFO] Installing packages:\n\t[${REQUIRED_PACKAGES[@]}]${FONT_DEFAULT}"
    sudo -u nobody yaourt -S --needed --noconfirm --noprogressbar "${REQUIRED_PACKAGES[@]}"
    echo -e "${FONT_SUCCESS}[SUCCESS] Installed packages:\n\t[${REQUIRED_PACKAGES[@]}]${FONT_DEFAULT}"
fi


echo -e "${FONT_INFO}[INFO] Getting python-${PYTHON_VERSION} source ...${FONT_DEFAULT}"
if [[ "${URL_PYTHON_SOURCE}" ]]; then
    curl --fail --silent --location "${URL_PYTHON_SOURCE}" | tar xz
else
    curl --fail --silent --location "${BASE_URL_PYTHON_SOURCE}${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz" | tar xz
fi
echo -e "${FONT_SUCCESS}[SUCCESS] Got python-${PYTHON_VERSION} source${FONT_DEFAULT}"
cd Python-${PYTHON_VERSION}


echo -e "${FONT_INFO}[INFO] Configure python-${PYTHON_VERSION}${FONT_DEFAULT}"
if [[ ! "${CFLAGS}" ]]; then
    if [[ -f "/etc/arch-release" ]] && [[ -s "/etc/makepkg.conf" ]]; then
        CFLAGS=$(egrep '^CFLAGS=".+"$' /etc/makepkg.conf | cut -d '"' -f2)
    fi
    if [[ ! "${CFLAGS}" ]]; then
        #CFLAGS='-march=native -O2 -pipe -fstack-protector-strong'
        CFLAGS='-march=x86-64 -mtune=generic -O2 -pipe -fstack-protector-strong'
    fi
fi
CFLAGS="${CFLAGS}" ./configure --enable-shared --enable-ipv6 --with-threads --with-signal-module --with-fpectl --prefix=${PREFIX}
sed --in-place -e 's/^\(#SSL=.\+\)/SSL=\/usr/g' Modules/Setup
sed --in-place -e 's/^#\(_ssl _ssl.c .\+\)/\1/g' Modules/Setup
sed --in-place -e 's/^#\(\s*-DUSE_SSL.\+\)/\1/g' Modules/Setup
sed --in-place -e 's/^#\(\s*-L\$(SSL)\/lib.\+\)/\1/g' Modules/Setup
sed --in-place -e 's/^#\(zlib .\+\)$/\1/g' Modules/Setup
echo -e "${FONT_SUCCESS}[SUCCESS] Configure python-${PYTHON_VERSION}${FONT_DEFAULT}"


echo -e "${FONT_INFO}[INFO] make python-${PYTHON_VERSION}${FONT_DEFAULT}"
LD_RUN_PATH=${PREFIX}/lib make -j $(grep -c ^processor /proc/cpuinfo | sed 's/^0$/1/')
echo -e "${FONT_SUCCESS}[SUCCESS] make python-${PYTHON_VERSION}${FONT_DEFAULT}"


echo -e "${FONT_INFO}[INFO] make install python-${PYTHON_VERSION}${FONT_DEFAULT}"
porg -lD make install
echo -e "${FONT_SUCCESS}[SUCCESS] make install python-${PYTHON_VERSION}${FONT_DEFAULT}"


cd ${BASE_WORKING_DIRECTORY}
rm -rf ${WORKING_DIRECTORY}
echo -e "${FONT_NOTICE}[NOTICE] Removed working directory [${WORKING_DIRECTORY}]${FONT_DEFAULT}"


echo -e "${FONT_INFO}[INFO] Customizing python-${PYTHON_VERSION}${FONT_DEFAULT}"
if [[ "${MAJOR_VERSION}" == "2" ]]; then
    echo -e "import sys\nsys.setdefaultencoding('utf-8')" > ${PREFIX}/lib/python${MAJOR_VERSION}.${MINOR_VERSION}/site-packages/sitecustomize.py
    #${PREFIX}/bin/python -m ensurepip --upgrade
    curl --fail --silent --location -O ${URL_PIP_INSTALLER}
    ${PREFIX}/bin/python get-pip.py
    rm -f get-pip.py
elif [[ "${MAJOR_VERSION}" == "3" ]]; then
    ${PREFIX}/bin/python${MAJOR_VERSION}.${MINOR_VERSION} -m ensurepip --upgrade
fi
${PREFIX}/bin/pip${MAJOR_VERSION} install --upgrade pip

if [[ "${REQUIRED_PYTHON_MODULES[@]}" ]];then
    ${PREFIX}/bin/pip${MAJOR_VERSION} install --upgrade "${REQUIRED_PYTHON_MODULES[@]}"
fi

echo -e "${FONT_SUCCESS}[SUCCESS] Customized python-${PYTHON_VERSION}${FONT_DEFAULT}"


echo -e "${FONT_SUCCESS}[SUCCESS] Finished ${SCRIPT_NAME}${FONT_DEFAULT}"
exit 0
