#!/bin/bash

# Thêm dữ liệu từ cấu hình
#source ../settings.sh

# Bắt đầu đếm thời gian thực thi script
start_time=$(date +%s)

# Xóa thư mục "out" nếu nó tồn tại
#rm -rf out

# Thư mục chính
MAINPATH=/home/$USER # thay đổi thành thư mục người dùng hiện tại

# Thư mục nhân kernel
KERNEL_DIR=$MAINPATH/kle
KERNEL_PATH=$KERNEL_DIR/android_kernel_blackshark_sm8250

git log $LAST..HEAD > ../log.txt
BRANCH=$(git branch --show-current)

# Thư mục bộ biên dịch
CLANG19_DIR=$KERNEL_DIR/clang19
ANDROID_PREBUILTS_GCC_ARM_DIR=$KERNEL_DIR/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9
ANDROID_PREBUILTS_GCC_AARCH64_DIR=$KERNEL_DIR/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9

# Kiểm tra và sao chép nếu cần thiết
check_and_clone() {
    local dir=$1
    local repo=$2

    if [ ! -d "$dir" ]; then
        echo "Thư mục $dir không tồn tại. Sao chép $repo."
        git clone $repo $dir
    fi
}

check_and_wget() {
    local dir=$1
    local repo=$2

    if [ ! -d "$dir" ]; then
        echo "Thư mục $dir không tồn tại. Tải về $repo."
        mkdir $dir
        cd $dir
        wget $repo
        tar -zxvf Clang-19.0.0git-20240625.tar.gz
        rm -rf Clang-19.0.0git-20240625.tar.gz
        cd ../android_kernel_xiaomi_kle
    fi
}

# Sao chép các công cụ biên dịch nếu chúng không tồn tại
check_and_wget $CLANG19_DIR https://github.com/ZyCromerZ/Clang/releases/download/19.0.0git-20240625-release/Clang-19.0.0git-20240625.tar.gz
check_and_clone $ANDROID_PREBUILTS_GCC_ARM_DIR https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9
check_and_clone $ANDROID_PREBUILTS_GCC_AARCH64_DIR https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9

# Thiết lập biến PATH
PATH=$CLANG19_DIR/bin:$ANDROID_PREBUILTS_GCC_AARCH64_DIR/bin:$ANDROID_PREBUILTS_GCC_ARM_DIR/bin:$PATH
export PATH
export ARCH=arm64

# Thư mục để xây dựng MagicTime
MAGIC_TIME_DIR="$KERNEL_DIR/MagicTime"

# Tạo thư mục MagicTime nếu nó không tồn tại
if [ ! -d "$MAGIC_TIME_DIR" ]; then
    mkdir -p "$MAGIC_TIME_DIR"
    
    # Kiểm tra và sao chép Anykernel nếu MagicTime không tồn tại
    if [ ! -d "$MAGIC_TIME_DIR/Anykernel" ]; then
        git clone https://github.com/konanguyen/Anykernel "$MAGIC_TIME_DIR/Anykernel"
        
        # Di chuyển tất cả các tệp từ Anykernel vào MagicTime
        mv "$MAGIC_TIME_DIR/Anykernel/"* "$MAGIC_TIME_DIR/"
        
        # Xóa thư mục Anykernel
        rm -rf "$MAGIC_TIME_DIR/Anykernel"
    fi
else
    # Nếu thư mục MagicTime tồn tại, kiểm tra xem .git có tồn tại không và xóa nếu có
    if [ -d "$MAGIC_TIME_DIR/.git" ]; then
        rm -rf "$MAGIC_TIME_DIR/.git"
    fi
fi

# Xuất các biến môi trường
export IMGPATH="$MAGIC_TIME_DIR/Image"
export DTBPATH="$MAGIC_TIME_DIR/dtb"
export DTBOPATH="$MAGIC_TIME_DIR/dtbo.img"
export CROSS_COMPILE="aarch64-linux-gnu-"
export CROSS_COMPILE_COMPAT="arm-linux-gnueabi-"
export KBUILD_BUILD_USER="Konadev"
export KBUILD_BUILD_HOST="SteamOS"
export MODEL="kle"

# Ghi thời gian xây dựng
MAGIC_BUILD_DATE=$(date '+%Y-%m-%d_%H-%M-%S')

# Thư mục cho kết quả xây dựng
output_dir=out

# Cấu hình nhân kernel
make O="$output_dir" \
            kle_defconfig

    # Biên dịch nhân kernel
    make -j $(nproc --all) \
                O="$output_dir" \
                CC="ccache clang" \
                HOSTCC=gcc \
                LD=ld.lld \
                AS=llvm-as \
                AR=llvm-ar \
                NM=llvm-nm \
                OBJCOPY=llvm-objcopy \
                OBJDUMP=llvm-objdump \
                STRIP=llvm-strip \
                LLVM=1 \
                LLVM_IAS=1 \
                CXXFLAGS=-O3 \
                2> ./.tmp_bug
                

# Biến DTS giả định đã được thiết lập từ trước trong script
find $DTS -name '*.dtb' -exec cat {} + > $DTBPATH
find $DTS -name 'Image' -exec cat {} + > $IMGPATH
find $DTS -name 'dtbo.img' -exec cat {} + > $DTBOPATH

# Kết thúc đếm thời gian thực thi script
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

cd "$KERNEL_PATH"

# Kiểm tra xem quá trình xây dựng có thành công hay không
if grep -q -E "Ошибка 2|Error 2" error.log; then
    cd "$KERNEL_PATH"
    echo "Lỗi: Quá trình xây dựng kết thúc với lỗi"

#    curl -s -X POST https://api.telegram.org/bot$TGTOKEN/sendMessage \
#    -d chat_id="@magictimekernel" \
#    -d text="Lỗi trong quá trình biên dịch!" \
#    -d message_thread_id="38153"

#    curl -s -X POST "https://api.telegram.org/bot$TGTOKEN/sendDocument?chat_id=@magictimekernel" \
#    -F document=@"./error.log" \
#    -F message_thread_id="38153"
else
    echo "Tổng thời gian thực thi: $elapsed_time giây"
    # Di chuyển vào thư mục MagicTime và tạo file nén
    cd "$MAGIC_TIME_DIR"
    7z a -mx9 MagicTime-$MODEL-$MAGIC_BUILD_DATE.zip * -x!*.zip
    
#    curl -s -X POST https://api.telegram.org/bot$TGTOKEN/sendMessage \
#    -d chat_id="@magictimekernel" \
#    -d text="Quá trình biên dịch thành công! Thời gian thực thi: $elapsed_time giây" \
#    -d message_thread_id="38153"

#    curl -s -X POST "https://api.telegram.org/bot$TGTOKEN/sendDocument?chat_id=@magictimekernel" \
#    -F document=@"./MagicTime-$MODEL-$MAGIC_BUILD_DATE.zip" \
#    -F caption="MagicTime ${VERSION}${PREFIX}${BUILD} (${BUILD_TYPE})" \
#    -F message_thread_id="38153"
    
#    curl -s -X POST "https://api.telegram.org/bot$TGTOKEN/sendDocument?chat_id=@magictimekernel" \
#    -F document=@"../log.txt" \
#    -F caption="Những thay đổi mới nhất" \
#    -F message_thread_id="38153"

 #   rm -rf MagicTime-$MODEL-$MAGIC_BUILD_DATE.zip

    BUILD=$((BUILD + 1))

    cd "$KERNEL_PATH"
    LAST=$(git log -1 --format=%H)

#    sed -i "s/LAST=.*/LAST=$LAST/" ../settings.sh
#    sed -i "s/BUILD=.*/BUILD=$BUILD/" ../settings.sh
fi
