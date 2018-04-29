#!/bin/sh

# MUSL Cross Compilers
export PATH=$PATH:$HOME/x-tools/x86_64-pc-linux-musl/bin
TARGET=x86_64-pc-linux-musl

MUSL_VERSION=1.1.19
LIBXML2_VERSION=2.9.8
LLVM_VERSION=6.0.0

MUSL=musl-$MUSL_VERSION
MUSL_FILE=$MUSL.tar.gz
MUSL_URL=https://www.musl-libc.org/releases/

LIBXML2=libxml2-$LIBXML2_VERSION
LIBXML2_FILE=$LIBXML2.tar.gz
LIBXML2_URL="ftp://xmlsoft.org/libxml2"

LLVM_URL=https://releases.llvm.org/$LLVM_VERSION
LLVM=llvm-$LLVM_VERSION
LLVM_FILE=$LLVM.src.tar.xz
LIBUNWIND=libunwind-$LLVM_VERSION
LIBUNWIND_FILE=$LIBUNWIND.src.tar.xz
LIBCXXABI=libcxxabi-$LLVM_VERSION
LIBCXXABI_FILE=$LIBCXXABI.src.tar.xz
LIBCXX=libcxx-$LLVM_VERSION
LIBCXX_FILE=$LIBCXX.src.tar.xz
COMPILER_RT=compiler-rt-$LLVM_VERSION
COMPILER_RT_FILE=$COMPILER_RT.src.tar.xz
CFE=cfe-$LLVM_VERSION
CFE_FILE=$CFE.src.tar.xz
LLD=lld-$LLVM_VERSION
LLD_FILE=$LLD.src.tar.xz


mkdir -p src

if [ ! -d src/$MUSL ]; then
  sh -c "cd src; curl -L -O $MUSL_URL/$MUSL_FILE"
  sh -c "cd src; bsdtar -xf $MUSL_FILE"
fi

if [ ! -d src/$LIBXML2 ]; then
  sh -c "cd src; curl -L -O $LIBXML2_URL/$LIBXML2_FILE"
  sh -c "cd src; bsdtar -xf $LIBXML2_FILE"
fi

if [ ! -d src/$LLVM ]; then
  sh -c "cd src; curl -L -O $LLVM_URL/$LLVM_FILE"
  sh -c "cd src; curl -L -O $LLVM_URL/$LIBUNWIND_FILE"
  sh -c "cd src; curl -L -O $LLVM_URL/$LIBCXXABI_FILE"
  sh -c "cd src; curl -L -O $LLVM_URL/$LIBCXX_FILE"
  sh -c "cd src; curl -L -O $LLVM_URL/$COMPILER_RT_FILE"
  sh -c "cd src; curl -L -O $LLVM_URL/$CFE_FILE"
  sh -c "cd src; curl -L -O $LLVM_URL/$LLD_FILE"
  mkdir -p src/$LLVM
  bsdtar -xf src/$LLVM_FILE -C src/$LLVM --strip 1
  mkdir -p src/$LLVM/projects/libunwind
  bsdtar -xf src/$LIBUNWIND_FILE -C src/$LLVM/projects/libunwind --strip 1
  mkdir -p src/$LLVM/projects/libcxxabi
  bsdtar -xf src/$LIBCXXABI_FILE -C src/$LLVM/projects/libcxxabi --strip 1
  mkdir -p src/$LLVM/projects/libcxx
  bsdtar -xf src/$LIBCXX_FILE -C src/$LLVM/projects/libcxx --strip 1
  mkdir -p src/$LLVM/projects/compiler-rt
  bsdtar -xf src/$COMPILER_RT_FILE -C src/$LLVM/projects/compiler-rt --strip 1
  mkdir -p src/$LLVM/tools/clang
  bsdtar -xf src/$CFE_FILE -C src/$LLVM/tools/clang --strip 1
  mkdir -p src/$LLVM/tools/lld
  bsdtar -xf src/$LLD_FILE -C src/$LLVM/tools/lld --strip 1
fi

mkdir -p build-stage-musl
sh -c "cd build-stage-musl; CC=clang \
	$PWD/src/$MUSL/configure \
	--prefix=/usr"
make -j12 -C build-stage-musl
DESTDIR=$PWD/stage make -C build-stage-musl install 

mkdir -p build-stage-libxml2
sh -c "cd build-stage-libxml2; CC=clang \
	CFLAGS=\"--sysroot=$PWD/stage --target=$TARGET\" \
	$PWD/src/$LIBXML2/configure \
	--without-zlib \
	--without-lzma \
	--without-python \
	--prefix=$PWD/stage/usr"
make -j12 -C build-stage-libxml2
make -C build-stage-libxml2 install

mkdir build-stage-llvm
sh -c "cd build-stage-llvm; cmake -GNinja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_CROSSCOMPILING=True \
	-DCMAKE_INSTALL_PREFIX=$PWD/stage/usr \
	-DCMAKE_C_COMPILER=$TARGET-gcc \
	-DCMAKE_CXX_COMPILER=$TARGET-g++ \
	-DCMAKE_EXE_LINKER_FLAGS=\"-static-libstdc++ \
	-static-libgcc \
	-L $PWD/stage/usr/lib \" \
	-DLIBXML2_INCLUDE_DIR=$PWD/stage/usr/include/libxml2 \
	-DLIBXML2_LIBRARY=$PWD/stage/usr/lib/libxml2.so \
	-DLIBXML2_XMLLINT_EXECUTABLE=$PWD/stage/usr/bin/xmllint \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGET \
	-DLLVM_TARGET_ARCH=X86 \
	-DLLVM_TARGETS_TO_BUILD=X86 \
	-DLLVM_ENABLE_EH=True \
	-DLLVM_ENABLE_RTTI=True \
	-DLLVM_ENABLE_LIBCXX=True \
	-DLLVM_ENABLE_LIBXML2=True \
	-DLLVM_TOOL_LTO_BUILD=False \
	-DCOMPILER_RT_BUILD_BUILTINS=True \
	-DCOMPILER_RT_BUILD_SANITIZERS=False \
	-DCOMPILER_RT_BUILD_XRAY=False \
	-DCOMPILER_RT_BUILD_LIBFUZZER=False \
	-DCOMPILER_RT_BUILD_PROFILE=False \
	-DLIBCXXABI_USE_LLVM_UNWINDER=True \
	-DLIBCXXABI_ENABLE_STATIC_UNWINDER=True \
	-DLIBCXX_HAS_MUSL_LIBC=True \
	-DLIBCXX_HAS_GCC_S_LIB=False \
	$PWD/src/$LLVM"

make -j12 -C build-stage-llvm
make -C build-stage-llvm install
