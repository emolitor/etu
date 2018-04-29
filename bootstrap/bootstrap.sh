#!/bin/sh

MUSL_VERSION=1.1.19
LIBXML2_VERSION=2.9.8
LLVM_VERSION=6.0.0

# You shouldn't have to change anything below here
TARGET=x86_64-pc-linux-musl

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


function init {
  mkdir -p src

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
}


function musl {
  init 

  if [ ! -d src/$MUSL ]; then
    sh -c "cd src; curl -L -O $MUSL_URL/$MUSL_FILE"
    sh -c "cd src; bsdtar -xf $MUSL_FILE"
  fi

  mkdir -p build-host-musl
  sh -c "cd build-host-musl; CC=clang \
	$PWD/src/$MUSL/configure \
	--prefix=$PWD/host"
  make -j12 -C build-host-musl
  make -C build-host-musl install 

  mkdir -p build-stage-musl
  sh -c "cd build-stage-musl; CC=clang \
	$PWD/src/$MUSL/configure \
	--prefix=/usr"
  make -j12 -C build-stage-musl
  DESTDIR=$PWD/stage make -C build-stage-musl install 
}


function libxml2 {
  init 

  if [ ! -d src/$LIBXML2 ]; then
    sh -c "cd src; curl -L -O $LIBXML2_URL/$LIBXML2_FILE"
    sh -c "cd src; bsdtar -xf $LIBXML2_FILE"
  fi

  mkdir -p build-stage-libxml2
  sh -c "cd build-stage-libxml2; CC=$PWD/host/bin/musl-clang \
	$PWD/src/$LIBXML2/configure \
	--without-zlib \
	--without-lzma \
	--without-python \
	--prefix=$PWD/stage/usr"
  make -j4 -C build-stage-libxml2
  make -C build-stage-libxml2 install
}


function libcxx {
  init 

  if [ ! -d src/$LIBUNWIND ]; then
    mkdir src/$LIBUNWIND
    bsdtar -xf src/$LIBUNWIND_FILE -C src/$LIBUNWIND --strip 1
    mkdir src/$LIBCXXABI
    bsdtar -xf src/$LIBCXXABI_FILE -C src/$LIBCXXABI --strip 1
    mkdir src/$LIBCXX
    bsdtar -xf src/$LIBCXX_FILE -C src/$LIBCXX --strip 1
  fi

  mkdir build-stage-libunwind
  sh -c "cd build-stage-libunwind; cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/stage/usr \
	-DCMAKE_C_COMPILER=$PWD/host/bin/musl-clang \
	-DCMAKE_CXX_COMPILER=clang++ \
	-DLLVM_PATH=$PWD/src/$LLVM \
	$PWD/src/$LIBUNWIND"

  make -j4 -C build-stage-libunwind
  make -C build-stage-libunwind install

  mkdir build-stage-libcxxabi
  sh -c "cd build-stage-libcxxabi; cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/stage/usr \
	-DCMAKE_C_COMPILER=$PWD/host/bin/musl-clang \
	-DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_SHARED_LINKER_FLAGS=-L$PWD/stage/usr/lib \
	-DLIBCXXABI_USE_LLVM_UNWINDER=True \
	-DLIBCXXABI_LIBUNWIND_PATH=$PWD/src/$LIBUNWIND \
	-DLIBCXXABI_LIBCXX_INCLUDES=$PWD/src/$LIBCXX/include \
	-DLLVM_PATH=$PWD/src/$LLVM \
	$PWD/src/$LIBCXXABI"

  make -j4 -C build-stage-libcxxabi
  make -C build-stage-libcxxabi install

  # Build libcxx against libstdc++
  mkdir build-prestage-libcxx
  sh -c "cd build-prestage-libcxx; cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/stage/usr \
	-DCMAKE_C_COMPILER=$PWD/host/bin/musl-clang \
	-DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_SHARED_LINKER_FLAGS=-L$PWD/stage/usr/lib \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS=$PWD/src/$LIBCXXABI/include \
	-DLIBCXX_CXX_ABI_LIBRARY_PATH=$PWD/stage/usr/local \
	-DLLVM_PATH=$PWD/src/$LLVM \
	$PWD/src/$LIBCXX"

  make -j4 -C build-prestage-libcxx

  # Build libcxx against libcxx compiled above
  mkdir build-stage-libcxx
  sh -c "cd build-stage-libcxx; cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/stage/usr \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_CXX_COMPILER=clang++ \
	-DCMAKE_C_FLAGS=\"--sysroot=$PWD/stage --target=$TARGET \" \
	-DCMAKE_CXX_FLAGS=\" \
		--sysroot=$PWD/stage \
		--target=$TARGET \
		-I$PWD/build-prestage-libcxx/include \" \
        -DCMAKE_EXE_LINKER_FLAGS=\" \
		-L$PWD/stage/usr/lib \
		-L$PWD/build-prestage-libcxx/lib \" \
        -DCMAKE_SHARED_LINKER_FLAGS=\" \
  		-L$PWD/stage/usr/lib  \
		-L$PWD/build-prestage-libcxx/lib \" \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS=$PWD/src/$LIBCXXABI/include \
	-DLIBCXX_CXX_ABI_LIBRARY_PATH=$PWD/stage/usr/local \
	-DLIBCXX_HAS_MUSL_LIBC=True \
	-DLIBCXX_HAS_GCC_S_LIB=False \
	-DLLVM_PATH=$PWD/src/$LLVM \
	$PWD/src/$LIBCXX"

  make -j4 -C build-stage-libcxx
  make -C build-stage-libcxx install
}


function clang {
  init

  mkdir build-host-clang
  sh -c "cd build-host-clang; cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/host \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_CXX_COMPILER=clang++ \
	$PWD/src/$LLVM"
  make -j12  -C build-host-clang llvm-tblgen clang-tblgen
  mkdir -p $PWD/host/bin
  cp $PWD/build-host-clang/bin/* $PWD/host/bin

  mkdir build-stage-clang
  sh -c "cd build-stage-clang; cmake -GNinja \
	-DCMAKE_CROSSCOMPILING=True \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/fakeroot \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_CXX_COMPILER=clang++ \
	-DCMAKE_C_FLAGS=\"--sysroot=$PWD/stage --target=$TARGET \" \
	-DCMAKE_CXX_FLAGS=\"--sysroot=$PWD/stage --target=$TARGET \" \
        -DCMAKE_EXE_LINKER_FLAGS=-L$PWD/stage/usr/lib \
        -DCMAKE_SHARED_LINKER_FLAGS=-L$PWD/stage/usr/lib \
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
	-DLIBUNWIND_USE_COMPILER_RT=True \
	-DCOMPILER_RT_BUILD_BUILTINS=True \
	-DCOMPILER_RT_BUILD_SANITIZERS=False \
	-DCOMPILER_RT_BUILD_XRAY=False \
	-DCOMPILER_RT_BUILD_LIBFUZZER=False \
	-DCOMPILER_RT_BUILD_PROFILE=False \
	-DLIBCXXABI_USE_COMPILER_RT=True \
	-DLIBCXXABI_USE_LLVM_UNWINDER=True \
	-DLIBCXXABI_ENABLE_STATIC_UNWINDER=True \
	-DLIBCXX_HAS_MUSL_LIBC=True \
	-DLIBCXX_HAS_GCC_S_LIB=False \
	-DLIBCXX_USE_COMPILER_RT=True \
	-DLLVM_TABLEGEN=$PWD/host/bin/llvm-tblgen \
	-DCLANG_TABLEGEN=$PWD/host/bin/clang-tblgen \
	$PWD/src/$LLVM"

#	-DCMAKE_CROSSCOMPILING=True \
#  make -j12 -C build-stage-llvm
#  make -C build-stage-llvm install
}


function clean {
  rm -rf $PWD/build-prestage-*
  rm -rf $PWD/stage
  rm -rf $PWD/build-stage-*
  rm -rf $PWD/host
  rm -rf $PWD/build-host-*
}


function distclean {
  rm -rf src
  clean
}


function all {
  musl
  libxml2
  libcxx
}


$@
