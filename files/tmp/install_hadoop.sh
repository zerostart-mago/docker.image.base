#!/usr/bin/bash

# Install hadoop


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
REQUIRED_PACKAGES=("jdk8-openjdk" "openssh")


function show_usage() {
    echo -e "${FONT_INFO}Usage: ${SCRIPT_NAME} [OPTIONS]${FONT_DEFAULT}"
    echo
    echo -e "${FONT_INFO}Options:${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ -h, --help ]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  [ -v, --version ]${FONT_DEFAULT}"
    echo -e "${FONT_INFO}  --hadoop-version \${HADOOP_VERSION}${FONT_DEFAULT}"
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
    '--hadoop-version' )
        if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then
            echo -e "${FONT_ERROR}[ERROR] ${SCRIPT_NAME}: option requires an argument -- ${1}${FONT_DEFAULT}" 1>&2
            echo
            show_usage
            exit 1
        fi
        HADOOP_VERSION=$2
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


if [ ! ${HADOOP_VERSION} ]; then
	echo -e "${FONT_ERROR}[ERROR] No hadoop version specified${FONT_DEFAULT}" 1>&2
    echo
	show_usage
	exit 1
fi


if [ ! ${PREFIX} ]; then
	PREFIX="/opt/local/hadoop-${HADOOP_VERSION}"
fi


URL_HADOOP_PACKAGE="http://apache.mirror.iphh.net/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
BASE_WORKING_DIRECTORY=$(dirname ${BASE_WORKING_DIRECTORY:-${TMPDIR:-/tmp}}/x)
WORKING_DIRECTORY=$(mktemp -d ${BASE_WORKING_DIRECTORY}/.build.hadoop-${HADOOP_VERSION}.XXXXXXXXXX)


echo
echo -e "${FONT_NOTICE}[NOTICE] Building hadoop ...${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --hadoop-version: ${HADOOP_VERSION}${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --prefix: ${PREFIX}${FONT_DEFAULT}"
echo -e "${FONT_NOTICE}  --base-working-dir: ${WORKING_DIRECTORY}${FONT_DEFAULT}"
echo

cd ${WORKING_DIRECTORY}


if [[ "${REQUIRED_PACKAGES[@]}" ]]; then
    echo -e "${FONT_INFO}[INFO] Installing packages:\n\t[${REQUIRED_PACKAGES[@]}]${FONT_DEFAULT}"
    sudo -u nobody yaourt -S --needed --noconfirm --noprogressbar "${REQUIRED_PACKAGES[@]}"
    echo -e "${FONT_SUCCESS}[SUCCESS] Installed packages:\n\t[${REQUIRED_PACKAGES[@]}]${FONT_DEFAULT}"
fi


echo -e "${FONT_INFO}[INFO] Getting hadoop-${HADOOP_VERSION} source ...${FONT_DEFAULT}"
curl --fail --silent --location "${URL_HADOOP_PACKAGE}" | tar xz
echo -e "${FONT_SUCCESS}[SUCCESS] Got hadoop-${HADOOP_VERSION} source${FONT_DEFAULT}"


echo -e "${FONT_INFO}[INFO] Configure hadoop-${HADOOP_VERSION}${FONT_DEFAULT}"
cp -apr hadoop-${HADOOP_VERSION}/etc hadoop-${HADOOP_VERSION}/.etc_original
chmod +x hadoop-${HADOOP_VERSION}/etc/hadoop/*-env.sh
mkdir -p --mode=0755 $(basename  ${PREFIX})
porg --log --package="hadoop-${HADOOP_VERSION}" -- mv hadoop-${HADOOP_VERSION} ${PREFIX}
porg --log --package="hadoop-${HADOOP_VERSION}" -+ -- touch ${PREFIX}/etc/hadoop/dfs.hosts.include
porg --log --package="hadoop-${HADOOP_VERSION}" -+ -- touch ${PREFIX}/etc/hadoop/dfs.hosts.exclude
sed -i "/^export JAVA_HOME/ s:.*:export JAVA_HOME=/usr/lib/jvm/default\nexport HADOOP_PREFIX=${PREFIX}\nexport HADOOP_HOME=${PREFIX}\n:" ${PREFIX}/etc/hadoop/hadoop-env.sh
sed -i "/^export HADOOP_CONF_DIR/ s:.*:export HADOOP_CONF_DIR=${PREFIX}/etc/hadoop/:" ${PREFIX}/etc/hadoop/hadoop-env.sh
# sed -i '/^export HADOOP_OPTS/ s:.*:export HADOOP_OPTS="${HADOOP_OPTS}":' ${PREFIX}/etc/hadoop/hadoop-env.sh
sed -i -e '/^[^#]*export HADOOP_OPTS/ s/.*/#&/' ${PREFIX}/etc/hadoop/hadoop-env.sh
echo -e "${FONT_SUCCESS}[SUCCESS] Configure hadoop-${HADOOP_VERSION}${FONT_DEFAULT}"


cd ${BASE_WORKING_DIRECTORY}
rm -rf ${WORKING_DIRECTORY}
echo -e "${FONT_NOTICE}[NOTICE] Removed working directory [${WORKING_DIRECTORY}]${FONT_DEFAULT}"


echo -e "${FONT_SUCCESS}[SUCCESS] Finished ${SCRIPT_NAME}${FONT_DEFAULT}"
exit 0

