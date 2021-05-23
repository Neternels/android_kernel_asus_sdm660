#!/usr/bin/bash
set > /tmp/old_vars.log
# -------------------------------------------------------------------------- #
# ----------------- NetEnerls Team ㉿ Development is Life ------------------ #
# -------------------------------------------------------------------------- #

    #---- Kernel directory
    #     |
    #     |---- neternels/
    #     |     |---- AnyKernel/
    #     |     |---- builds/
    #     |     |---- logs/
    #     |     |---- out/
    #     |     |---- toolchains/
    #     |     |     |---- clang/
    #     |     |     |---- gcc/
    #     |     |     |---- proton/
    #     |     |
    #     |     |---- tools/
    #     |     |     |---- zipsigner.jar
    #     |
    #     |---- neternels.sh
    #     |---- neternels_secret.sh

# -------------------------------------------------------------------------- #
# ------------------------ BASIC CONFIGURATION ----------------------------- #
# -------------------------------------------------------------------------- #

# Build date
TIMEZONE=Europe/Paris
DATE=$(TZ=${TIMEZONE} date +%Y-%m-%d)

# Device codename (enter your device codename)
CODENAME=default

# Builder (displayed in proc/version)
BUILDER=darkmaster
HOST=grm34
if [[ ${BUILDER} == default ]]; then BUILDER=$(whoami); fi
if [[ ${HOST} == default ]]; then BUILDER=$(host); fi
export KBUILD_BUILD_USER=${BUILDER}
export KBUILD_BUILD_HOST=${HOST}

# Default compiler: PROTON / CLANG / GCC
DEFAULT_COMPILER=PROTON

# Kernel variant
KERNEL_VARIANT=CAF

# Paths
KERNEL_DIR=${PWD}
COMPILER_DIR=${KERNEL_DIR}/neternels
TOOLCHAINS_DIR=${COMPILER_DIR}/toolchains
OUT_DIR=${COMPILER_DIR}/out

# Toolchains URL
PROTON="https://github.com/kdrag0n/proton-clang"
CLANG="https://android.googlesource.com/platform/prebuilts/clang/\
host/linux-x86"
GCC_64="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/\
aarch64/aarch64-linux-android-4.9"
GCC_32="https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/\
arm/arm-linux-androideabi-4.9"

# AnyKernel URL
ANYKERNEL="https://github.com/grm34/AnyKernel3-X00TD.git"

# ZipSigner URL
ZIPSIGNER_URL="https://raw.githubusercontent.com/baalajimaestro/AnyKernel2/\
master/zipsigner-3.0.jar"

# Telegram settings (import sensitive data stored in neternels_secret.sh)
if [ ! -f neternels_secret.sh ]; then
    printf \
        '#!/usr/bin/bash\nexport CHATID=""\nexport BOT=""\nexport TOKEN=""' \
        > "${KERNEL_DIR}"/neternels_secret.sh
fi
# shellcheck disable=SC1091
source neternels_secret.sh
TELEGRAM_ID=${CHATID}
TELEGRAM_BOT=${BOT}
TELEGRAM_TOKEN=${TOKEN}
API="https://api.telegram.org/${TELEGRAM_BOT}:${TELEGRAM_TOKEN}"

# -------------------------------------------------------------------------- #
# ------------------------ SCRIPT CONFIGURATION ---------------------------- #
# -------------------------------------------------------------------------- #
# Shell color codes
RED="\e[1;31m"; GREEN="\e[1;32m"; YELLOW="\e[1;33m"
BLUE="\e[1;34m"; CYAN="\e[1;36m"; BOLD="\e[1;37m"; NC="\e[0m"

# Display script banner
_banner() {
    echo -e "${BOLD}
   ┌─────────────────────────────────────────────┐
   │ ┏┓╻┏━╸╺┳╸┏━╸┏━┓┏┓╻┏━╸╻  ┏━┓   ╺┳╸┏━╸┏━┓┏┓┏┓ │
   │ ┃┗┫┣╸  ┃ ┣╸ ┣┳┛┃┗┫┣╸ ┃  ┗━┓ ㉿ ┃ ┣╸ ┣╸┫┃┗┛┃ │
   │ ╹ ╹┗━╸ ╹ ┗━╸╹┗╸╹ ╹┗━╸┗━╸┗━┛    ╹ ┗━╸╹ ╹╹  ╹ │
   └─────────────────────────────────────────────┘"
}

# Ask some information
_prompt() {
    LENTH=${*}; COUNT=${#LENTH}
    echo -ne "\n${YELLOW}==> ${GREEN}${1} ${RED}${2}"
    echo -ne "${YELLOW}\n==> "
    for (( CHAR=1; CHAR<=COUNT; CHAR++ )); do echo -ne "-"; done
    echo -ne "\n==> ${NC}"
}

# Ask confirmation (Yes/No)
_confirm() {
    CONFIRM=True; COUNT=$(( ${#1} + 6 ))
    until [[ ${CONFIRM} =~ ^(y|n|Y|N|yes|no|Yes|No|YES|NO) ]] || \
            [[ ${CONFIRM} == "" ]]; do
        echo -ne "${YELLOW}\n==> ${GREEN}${1} ${RED}[Y/n]${YELLOW}\n==> "
        for (( CHAR=1; CHAR<=COUNT; CHAR++ )); do echo -ne "-"; done
        echo -ne "\n==> ${NC}"
        read -r CONFIRM
    done
}

# Select an option
_select() {
    COUNT=0
    echo -ne "${YELLOW}\n==> "
    for ENTRY in "${@}"; do
        echo -ne "${GREEN}${ENTRY} ${RED}[$(( ++COUNT ))] ${NC}"
    done
    LENTH=${*}; NUMBER=$(( ${#*} * 4 ))
    COUNT=$(( ${#LENTH} + NUMBER + 1 ))
    echo -ne "${YELLOW}\n==> "
    for (( CHAR=1; CHAR<=COUNT; CHAR++ )); do echo -ne "-"; done
    echo -ne "\n==> ${NC}"
}

# Display some notes
_note() {
    echo -e "${YELLOW}\n[$(date +%T)] ${CYAN}${1}${NC}"; sleep 1
}

# Display error
_error() {
    echo -e "\n${RED}Error: ${YELLOW}${*}${NC}"
}

# Check command status and exit on error
_check() {
    "${@}"; local STATUS=$?
    if [[ ${STATUS} -ne 0 ]]; then
        _error "${@}"
        _exit
    fi
    return "${STATUS}"
}

# Exit with 5s timeout
_exit() {
    _send_failed
    _clean_anykernel
    for (( SECOND=5; SECOND>=1; SECOND-- )); do
        echo -ne "\r\033[K${BLUE}Exit building script in ${SECOND}s...${NC}"
        sleep 1
    done
    echo && sudo kill 9 $$ && exit
}

# Download show progress bar only
_wget() {
    wget -O "${1}" --quiet --show-progress "${2}"
}

# Say goodbye
_goodbye_msg() {
    echo -e "\n${GREEN}<<< NetEnerls Team ㉿ Development is Life >>>${NC}"
}

# -------------------------------------------------------------------------- #
# ------------------------ TELEGRAM CONFIGURATION -------------------------- #
# -------------------------------------------------------------------------- #

_send_msg() {
    curl -fsSL -X POST "${API}"/sendMessage \
        -d "parse_mode=html" \
        -d "chat_id=${TELEGRAM_ID}" \
        -d "text=${1}" \
        &>/dev/null
}

_send_build() {
    curl -fsSL -X POST -F document=@"${1}" "${API}"/sendDocument \
        -F "chat_id=${TELEGRAM_ID}" \
        -F "disable_web_page_preview=true" \
        -F "caption=${2}" \
        &>/dev/null
}

_send_failed() {
    if [[ ${START_TIME} ]] && [[ ! $BUILD_TIME ]]; then
        END_TIME=$(TZ=${TIMEZONE} date +%s)
        BUILD_TIME=$((END_TIME - START_TIME))
        _send_msg "<b>${CODENAME}-${LINUX_VERSION}</b> | \
Build failed to compile after $((BUILD_TIME / 60)) minutes \
and $((BUILD_TIME % 60)) seconds</code>"
        _send_build "${LOG}" "<b>${CODENAME}-${LINUX_VERSION} build logs</b>"
    fi
}

# -------------------------------------------------------------------------- #
# ---------------------------- REQUIREMENTS -------------------------------- #
# -------------------------------------------------------------------------- #

_install_dependencies() {

    # Set the package manager of the current Linux distribution
    declare -A PMS=([redhat]=yum [arch]=pacman [gentoo]=emerge
        [suse]=zypp [fedora]=dnf)
    OS=(redhat arch gentoo suse fedora)
    PM=apt-get
    for x in "${OS[@]}"; do
        if uname -v | grep -qi "${x}"; then
            PM=${PMS[${x}]}
            break
        fi
    done

    # Install missing dependencies
    DEPENDENCIES=(wget curl git zip llvm-ar lld make automake)
    for PACKAGE in "${DEPENDENCIES[@]}"; do
        if ! which "${PACKAGE}" &>/dev/null; then
            PACKAGE=${PACKAGE//-ar/}
            _note "Package: ${PACKAGE} not found! Installing..."
            _check sudo "${PM}" install -y "${PACKAGE}"
        fi
    done
}

_clone_toolchains() {
    case ${COMPILER} in
        PROTON)
            if [[ ! -d ${TOOLCHAINS_DIR}/proton ]]; then
                _note "Proton repository not found! Cloning..."
                _check git clone --depth=1 ${PROTON} \
                    "${TOOLCHAINS_DIR}"/proton
            fi
            ;;

        CLANG)
            if [[ ! -d ${TOOLCHAINS_DIR}/clang ]]; then
                _note "Clang repository not found! Cloning..."
                _check git clone ${CLANG} "${TOOLCHAINS_DIR}"/clang
            elif [[ ! -d ${TOOLCHAINS_DIR}/gcc64 ]]; then
                _note "GCC aarch64 repository not found! Cloning..."
                _check git clone ${GCC_64} "${TOOLCHAINS_DIR}"/gcc64
            fi
            ;;

        GCC)
            if [[ ! -d ${TOOLCHAINS_DIR}/gcc32 ]]; then
                _note "GCC arm repository not found! Cloning..."
                _check git clone ${GCC_32} "${TOOLCHAINS_DIR}"/gcc32
            elif [[ ! -d ${TOOLCHAINS_DIR}/gcc64 ]]; then
                _note "GCC aarch64 repository not found! Cloning..."
                _check git clone ${GCC_64} "${TOOLCHAINS_DIR}"/gcc64
            fi
    esac
}

_clone_anykernel() {
    if [[ ! -d ${COMPILER_DIR}/AnyKernel ]]; then
        _note "AnyKernel repository not found! Cloning..."
        _check git clone ${ANYKERNEL} "${COMPILER_DIR}"/AnyKernel
    fi
}

_download_zipsigner() {
    if [[ ! -f ${COMPILER_DIR}/tools/zipsigner.jar ]]; then
        _note "Zipsigner not found! Downloading..."
        _check _wget "${COMPILER_DIR}"/tools/zipsigner.jar "${ZIPSIGNER_URL}"
    fi
}

# -------------------------------------------------------------------------- #
# ------------------------- USER CONFIGURATION ----------------------------- #
# -------------------------------------------------------------------------- #

_ask_for_toolchain() {
    _confirm "Do you wish to use default compiler (${DEFAULT_COMPILER})?"
    case ${CONFIRM} in
        n|N|no|No|NO)
            _note "Select Toolchain compiler:"
            TOOLCHAINS=(PROTON CLANG GCC)
            until [[ ${COMPILER} =~ ^[1-2]$ ]]; do
                _select PROTON CLANG GCC
                read -r COMPILER
            done
            COMPILER=${TOOLCHAINS[${COMPILER}]}
            ;;
        *)
            COMPILER=${DEFAULT_COMPILER}
    esac
}

_ask_for_codename() {
    if [ ${CODENAME} == default ]; then
        _prompt "Enter android device codename (e.q. X00TD)"
        read -r CODENAME
    fi
}

_ask_for_defconfig() {
    until [ -f arch/arm64/configs/"${DEFCONFIG}" ]; do
        _prompt "Enter defconfig name (e.q. neternels_defconfig)"
        read -r DEFCONFIG
    done
}

_ask_for_menuconfig() {
    _confirm "Do you wish to edit kernel with menuconfig"
    case ${CONFIRM} in
        n|N|no|No|NO)
            MENUCONFIG=False
            ;;
        *)
            MENUCONFIG=True
    esac
}

_ask_for_cores() {
    _confirm "Do you wish to use all availables CPU Cores?"
    case ${CONFIRM} in
        n|N|no|No|NO)
            until [[ ${CORES} =~ ^[1-9]{1}[0-9]{0,1}$ ]]; do
                _prompt "Enter amount of cores to use"
                read -r CORES
            done
            ;;
        *)
            CORES="--all"
    esac
}

_clean_anykernel() {
    _note "Cleaning AnyKernel folder..."
    UNWANTED=(Image.gz-dtb init.spectrum.rc)
    for UW in "${UNWANTED[@]}"; do
        rm -f "${COMPILER_DIR}"/AnyKernel/"${UW}"
    done
    if [ ! -f "${COMPILER_DIR}/builds/NetErnels-${CODENAME}-\
${LINUX_VERSION}-${DATE}-signed.zip" ]; then
        rm -f "${COMPILER_DIR}"/AnyKernel/*.zip
    fi
    if [[ -f ${COMPILER_DIR}/AnyKernel/anykernel-real.sh ]]; then
        rm -f "${COMPILER_DIR}"/AnyKernel/anykernel.sh
    fi
}

# -------------------------------------------------------------------------- #
# --------------------------- KERNEL BUILDING ------------------------------ #
# -------------------------------------------------------------------------- #

_make_clean_build() {
    _confirm "Do you wish to make clean build (${LINUX_VERSION})?"
    case ${CONFIRM} in
        n|N|no|No|NO)
            _note "Make dirty build (this could take a while)..."
            _check make clean && make mrproper && _clean_anykernel
            ;;
        *)
            _note "Make clean build (this could take a while)..."
            _check make clean && make mrproper && \
                rm -rf "${OUT_DIR}" && _clean_anykernel
    esac
}

_make_defconfig() {
    _note "Make ${DEFCONFIG} (${LINUX_VERSION})..."
    _send_msg "<b>${CODENAME}-${LINUX_VERSION}</b> | \
<code>New build started by ${BUILDER} with ${COMPILER} compiler</code>"
    _check make O="${OUT_DIR}" ARCH=arm64 "${DEFCONFIG}"
}

_make_menuconfig() {
    if [ ${MENUCONFIG} == True ]; then
        _note "Make menuconfig..."
        _send_msg "<b>${CODENAME}-${LINUX_VERSION}</b> | \
<code>Started menuconfig</code>"
        _check make O="${OUT_DIR}" ARCH=arm64 menuconfig "${OUT_DIR}"/.config

        _confirm "Do you wish to save and use ${DEFCONFIG}"
        case ${CONFIRM} in
            n|N|no|No|NO)
                _confirm "Do you wish to continue"
                case ${CONFIRM} in
                    n|N|no|No|NO)
                        _error "aborted by user!"
                        _exit
                        ;;
                    *)
                        return
                esac
                ;;
            *)
                _note "Saving ${DEFCONFIG} in arch/arm64/configs..."
                _check cp arch/arm64/configs/"${DEFCONFIG}" \
                    arch/arm64/configs/"${DEFCONFIG}"_save
                _check cp "${OUT_DIR}"/.config \
                    arch/arm64/configs/"${DEFCONFIG}"
        esac
    fi
}

_make_build() {
    _note "Starting new build for ${CODENAME} (${LINUX_VERSION})..."
    _send_msg "<b>${CODENAME}-${LINUX_VERSION}</b> | \
<code>Started compiling kernel</code>"
    case ${COMPILER} in

        PROTON)
            export PATH=${TOOLCHAINS_DIR}/proton/bin:/usr/bin:${PATH}
            _check make -j"$(nproc ${CORES})" \
                O="${OUT_DIR}" \
                ARCH=arm64 \
                SUBARCH=arm64 \
                CROSS_COMPILE=aarch64-linux-gnu- \
                CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
                CC=clang \
                AR=llvm-ar \
                OBJDUMP=llvm-objdump \
                STRIP=llvm-strip
            ;;

        CLANG)
            export PATH=\
${TOOLCHAINS_DIR}/clang/bin:${TOOLCHAINS_DIR}/gcc64/bin:\
${TOOLCHAINS_DIR}/gcc32/bin:/usr/bin:${PATH}
            _check make -j"$(nproc ${CORES})" \
                O="${OUT_DIR}" \
                ARCH=arm64 \
                SUBARCH=arm64 \
                CC=clang \
                CLANG_TRIPLE=aarch64-linux-gnu- \
                CROSS_COMPILE=aarch64-linux-android- \
                CROSS_COMPILE_ARM32=arm-linux-androideabi-
            ;;

        GCC)
            export PATH=\
${TOOLCHAINS_DIR}/gcc32/bin:${TOOLCHAINS_DIR}/gcc64/bin:/usr/bin/:${PATH}
            _check make -j"$(nproc ${CORES})"  \
                O="${OUT_DIR}" \
                ARCH=arm64 \
                SUBARCH=arm64 \
                CROSS_COMPILE=aarch64-linux-android- \
                CROSS_COMPILE_ARM32=arm-linux-androideabi-
    esac
}

# -------------------------------------------------------------------------- #
# ------------------------- MAKE FLASHABLE ZIP ----------------------------- #
# -------------------------------------------------------------------------- #

_create_flashable_zip() {
    _note "Creating ${LINUX_VERSION}-${CODENAME}-NetErnels-${DATE}.zip..."
    _send_msg "<b>${CODENAME}-${LINUX_VERSION}</b> | \
<code>Started flashable zip creation</code>"

    # Move GZ-DTB to AnyKernel folder
	_check cp "$OUT_DIR"/arch/arm64/boot/Image.gz-dtb \
        "${COMPILER_DIR}"/AnyKernel/

    # CD to AnyKernel folder
	cd "${COMPILER_DIR}"/AnyKernel || (_error "AnyKernel not found!"; _exit)

    # Create init.spectrum.rc
    if [[ -f ${KERNEL_DIR}/init.ElectroSpectrum.rc ]]; then
        _check cp -af "${KERNEL_DIR}"/init.ElectroSpectrum.rc \
            init.spectrum.rc
        _check sed -i "s/persist.spectrum.kernel.*/persist.spectrum.kernel \
${LINUX_VERSION}-${CODENAME}-NetErnels/g" init.spectrum.rc
    fi

    # Create anykernel.sh
    if [[ -f anykernel-real.sh ]]; then
        _check cp -af anykernel-real.sh anykernel.sh
    fi

    # Set anykernel.sh
	_check sed -i "s/kernel.string=.*/kernel.string=\
NetErnels-${CODENAME}/g" anykernel.sh
	_check sed -i \
        "s/kernel.for=.*/kernel.for=${KERNEL_VARIANT}/g" anykernel.sh
	_check sed -i \
        "s/kernel.compiler=.*/kernel.compiler=${COMPILER}/g" anykernel.sh
	_check sed -i "s/kernel.made=.*/kernel.made=${BUILDER}/g" anykernel.sh
	_check sed -i "\
        s/kernel.version=.*/kernel.version=$LINUX_VERSION/g" anykernel.sh
	_check sed -i "s/message.word=.*/message.word=NetEnerls ~ \
Development is Life ~ t.me\/neternels/g" anykernel.sh
	_check sed -i "s/build.date=.*/build.date=$DATE/g" anykernel.sh

	# Create flashable zip
	_check zip -r9 NetErnels-"${CODENAME}"-"${LINUX_VERSION}"-"${DATE}".zip \
./* -x .git README.md ./*placeholder
    cd "${KERNEL_DIR}" || (_error "${KERNEL_DIR} not found!"; _exit)
}

_sign_flashable_zip() {
    _note "Signing Zip file with AOSP keys..."
    _send_msg "<b>${CODENAME}-${LINUX_VERSION}</b> | \
<code>Signing Zip file with AOSP keys</code>"
    _check java -jar "${COMPILER_DIR}"/tools/zipsigner.jar \
"${COMPILER_DIR}"/AnyKernel/NetErnels-"${CODENAME}"-"${LINUX_VERSION}"-\
"${DATE}".zip "${COMPILER_DIR}"/builds/NetErnels-"${CODENAME}"-\
"${LINUX_VERSION}"-"${DATE}"-signed.zip
}

# -------------------------------------------------------------------------- #
# ------------------------- START THE SCRIPT ------------------------------- #
# -------------------------------------------------------------------------- #
_banner
_note "Starting new kernel build on ${DATE} (...)"

# Ban all n00bz
trap '_error keyboard interrupt!; _exit' 1 2 3 6
if [[ $(uname) != Linux ]]; then
    _error "run this script on Linux!"
    _exit
elif [ ! -d kernel ] || [ ! -f AndroidKernel.mk ] || [ ! -f Makefile ]; then
    _error "run this script from an android kernel tree!"
    _exit
fi

# Create missing folders
FOLDERS=(builds tools logs)
for FOLDER in "${FOLDERS[@]}"; do
    if [[ ! -d ${COMPILER_DIR}/${FOLDER} ]]; then
        mkdir -p "${COMPILER_DIR}"/"${FOLDER}"
    fi
done

# Get user configuration
_ask_for_toolchain
_ask_for_codename
_ask_for_defconfig
_ask_for_menuconfig
_ask_for_cores

# Set logs
TIME=$(TZ=${TIMEZONE} date +%H-%M-%S)
LOG=${COMPILER_DIR}/logs/${CODENAME}_${DATE}_${TIME}.log
printf "NetEnerls Team ㉿ Development is Life\n" > "${LOG}"

# Install and clone requirements
_install_dependencies | tee -a "${LOG}"
_clone_toolchains | tee -a "${LOG}"
_clone_anykernel | tee -a "${LOG}"
_download_zipsigner | tee -a "${LOG}"

# Make
_note "Make kernel version..."
LINUX_VERSION=$(make kernelversion)
_make_clean_build | tee -a "${LOG}"
_make_defconfig | tee -a "${LOG}"
_make_menuconfig
_confirm "Do you wish to start NetErnels-${CODENAME}-${LINUX_VERSION}"
case ${CONFIRM} in
    n|N|no|No|NO)
        _error "aborted by user!"
        _exit
        ;;
    *)
        START_TIME=$(TZ=${TIMEZONE} date +%s)
        _make_build | tee -a "${LOG}"
        sleep 5
esac

# Send build status to Telegram
END_TIME=$(TZ=${TIMEZONE} date +%s)
BUILD_TIME=$((END_TIME - START_TIME))
_note "Successfully compiled \
NetErnels-${CODENAME}-${LINUX_VERSION}-${DATE}-signed.zip"
_send_msg "<b>${CODENAME}-${LINUX_VERSION}</b> | \
<code>Kernel Successfully Compiled after $((BUILD_TIME / 60)) minutes and \
$((BUILD_TIME % 60)) seconds</code>"

# Flashable zip
_create_flashable_zip | tee -a "${LOG}"
_sign_flashable_zip | tee -a "${LOG}"

# Upload build on Telegram
_note "Uploading build on Telegram..."
MD5=$(md5sum "${COMPILER_DIR}/builds/NetErnels-${CODENAME}-\
${LINUX_VERSION}-${DATE}-signed.zip" | cut -d' ' -f1)
_send_build "${COMPILER_DIR}/builds/NetErnels-${CODENAME}-\
${LINUX_VERSION}-${DATE}-signed.zip" "<b>${CODENAME}-\
${LINUX_VERSION}</b> | <b>MD5 Checksum</b>: <code>${MD5}</code>"

# Get clean inputs logs
set | grep -v "RED=\|GREEN=\|YELLOW=\|BLUE=\|CYAN=\|BOLD=\|NC=\|\
TELEGRAM_ID=\|TELEGRAM_TOKEN=\|TELEGRAM_BOT\|API=\|CHATID=\|BOT=\|TOKEN=\|\
CONFIRM\|COUNT=\|LENTH=\|NUMBER=\|BASH_ARGC=\|BASH_REMATCH=\|CHAR=\|\
COLUMNS=\|LINES=\|PIPESTATUS=\|TIME=" > /tmp/new_vars.log
printf "\n### SELECTED INPUTS ###\n" >> "${LOG}"
diff /tmp/old_vars.log /tmp/new_vars.log | grep -E \
    "^> [A-Z_]{3,18}=" >> "${LOG}"

# Exit
_clean_anykernel && _goodbye_msg && _exit

# -------------------------------------------------------------------------- #
# ----------------- NetEnerls Team ㉿ Development is Life ------------------ #
# -------------------------------------------------------------------------- #
