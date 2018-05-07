#!/bin/sh

MUSL_VERSION=1.1.19
LIBICU_VERSION=61.1
LIBXML2_VERSION=2.9.8
LLVM_VERSION=6.0.0

# You shouldn't have to change anything below here
TARGET=x86_64-linux-musl

MUSL=musl-$MUSL_VERSION
MUSL_FILE=$MUSL.tar.gz
MUSL_URL=https://www.musl-libc.org/releases/


LIBICU=icu4c-`echo $LIBICU_VERSION | sed 's/\./_/'`
LIBICU_FILE=$LIBICU-src.tgz
LIBICU_URL=http://download.icu-project.org/files/icu4c/$LIBICU_VERSION

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


init() {

  if [ ! -d $PWD/src ]; then
    mkdir -p $PWD/src

    sh -c "cd src; git clone https://github.com/richfelker/musl-cross-make"
    echo "TARGET=x86_64-linux-musl" > $PWD/src/musl-cross-make/config.mak
    echo "OUTPUT=$PWD/host_gcc" >> $PWD/src/musl-cross-make/config.mak
    echo "DL_CMD=curl -C - -L -o" >> $PWD/src/musl-cross-make/config.mak
    echo "COMMON_CONFIG+=CFLAGS=\"-Os\" CXXFLAGS=\"-Os\" LDFLAGS=\"-s\"" >> $PWD/src/musl-cross-make/config.mak

    sh -c "cd src; curl -L -O $MUSL_URL/$MUSL_FILE"
#    sh -c "cd src; curl -L -O $LIBICU_URL/$LIBICU_FILE"
#    sh -c "cd src; curl -L -O $LIBXML2_URL/$LIBXML2_FILE"
    sh -c "cd src; curl -L -O $LLVM_URL/$LLVM_FILE"
    sh -c "cd src; curl -L -O $LLVM_URL/$LIBUNWIND_FILE"
    sh -c "cd src; curl -L -O $LLVM_URL/$LIBCXXABI_FILE"
    sh -c "cd src; curl -L -O $LLVM_URL/$LIBCXX_FILE"
    sh -c "cd src; curl -L -O $LLVM_URL/$COMPILER_RT_FILE"
    sh -c "cd src; curl -L -O $LLVM_URL/$CFE_FILE"
    sh -c "cd src; curl -L -O $LLVM_URL/$LLD_FILE"

    sh -c "cd src; bsdtar -xf $MUSL_FILE"

#    mkdir -p src/$LIBICU
#    bsdtar -xf src/$LIBICU_FILE -C src/$LIBICU --strip 1

#    sh -c "cd src; bsdtar -xf $LIBXML2_FILE"

    #mkdir -p src/$LIBUNWIND
    #bsdtar -xf src/$LIBUNWIND_FILE -C src/$LIBUNWIND --strip 1
    #mkdir -p src/$LIBCXXABI
    #bsdtar -xf src/$LIBCXXABI_FILE -C src/$LIBCXXABI --strip 1
    #mkdir -p src/$LIBCXX
    #bsdtar -xf src/$LIBCXX_FILE -C src/$LIBCXX --strip 1

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


host_gcc() {
  init 

  make -j12 -C $PWD/src/musl-cross-make
  make -C $PWD/src/musl-cross-make install
}

stage_clang() {
  init
  
  mkdir build-host-clang
  sh -c "cd build-stage-clang; cmake -GNinja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/stage \
	-DCMAKE_SHARED_LINKER_FLAGS=-L$PWD/build-stage-clang/lib \
	-DCOMPILER_RT_BUILD_SANITIZERS=False \
	-DCOMPILER_RT_BUILD_XRAY=False \
	-DCOMPILER_RT_BUILD_LIBFUZZER=False \
	-DLIBCXXABI_ENABLE_STATIC_UNWINDER=True \
	-DLIBCXXABI_USE_LLVM_UNWINDER=True \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS=$PWD/src/$LLVM/projects/libcxxabi/include \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGET \
	-DLLVM_ENABLE_EH=True \
	-DLLVM_ENABLE_RTTI=True \
	-DCLANG_BUILD_EXAMPLES=False \
	-DCLANG_DEFAULT_CXX_STDLIB=libc++ \
	-DCLANG_DEFAULT_LINKER=lld \
	-DCLANG_DEFAULT_RTLIB=compiler-rt \
	$PWD/src/$LLVM"

  exit

  make -j8 -C build-stage-libcxx compiler-rt install-compiler-rt
  make -j8 -C build-stage-libcxx unwind install-unwind
  make -j8 -C build-stage-libcxx cxxabi install-cxxabi
  make -j8 -C build-stage-libcxx cxx install-cxx
  make -j8 -C build-stage-libcxx lld install-lld
  make -j8 -C build-stage-libcxx clang install-clang
}

host_clang() {
  init

  export PATH=$PWD/host_gcc/bin:$PATH

  mkdir -p build-host-musl
  sh -c "cd build-host-musl; \
	CC=$TARGET-gcc \
	$PWD/src/$MUSL/configure \
	--syslibdir=$PWD/host_clang/lib \
	--prefix=$PWD/host_clang"
  make -j8 -C build-host-musl
  make -C build-host-musl install 

  mkdir build-host-clang
  sh -c "cd build-host-clang; cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_CROSSCOMPILING=True \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_INSTALL_PREFIX=$PWD/host_clang \
	-DCMAKE_C_COMPILER=$TARGET-gcc \
	-DCMAKE_CXX_COMPILER=$TARGET-g++ \
	-DCMAKE_SHARED_LINKER_FLAGS=-L$PWD/build-host-clang/lib \
	-DCOMPILER_RT_BUILD_SANITIZERS=False \
	-DCOMPILER_RT_BUILD_XRAY=False \
	-DCOMPILER_RT_BUILD_LIBFUZZER=False \
	-DLIBCXXABI_USE_LLVM_UNWINDER=True \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS=$PWD/src/$LLVM/projects/libcxxabi/include \
	-DLIBCXX_HAS_MUSL_LIBC=True \
	-DLIBCXX_HAS_GCC_S_LIB=False \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGET \
	-DLLVM_ENABLE_EH=True \
	-DLLVM_ENABLE_RTTI=True \
	-DLLVM_ENABLE_LIBCXX=True \
	-DCLANG_BUILD_EXAMPLES=False \
	-DCLANG_DEFAULT_CXX_STDLIB=libc++ \
	-DCLANG_DEFAULT_LINKER=lld \
	-DCLANG_DEFAULT_RTLIB=compiler-rt \
	$PWD/src/$LLVM"
 
  exit

  make -j8 -C build-host-clang install-compiler-rt
  make -j8 -C build-host-clang install-unwind
  make -j8 -C build-host-clang install-cxxabi
  make -j8 -C build-host-clang install-cxx
  make -j8 -C build-host-clang install-lld
  make -j8 -C build-host-clang install-clang
}



host_clang_old() {
  init
  
  mkdir build-host-clang
  sh -c "cd build-host-clang; cmake -GNinja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/host \
	-DCOMPILER_RT_BUILD_SANITIZERS=False \
	-DCOMPILER_RT_BUILD_XRAY=False \
	-DCOMPILER_RT_BUILD_LIBFUZZER=False \
	-DLIBCXXABI_USE_LLVM_UNWINDER=True \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS=$PWD/src/$LLVM/projects/libcxxabi/include \
	-DLIBCXX_HAS_MUSL_LIBC=True \
	-DLIBCXX_HAS_GCC_S_LIB=False \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGET \
	-DLLVM_ENABLE_EH=True \
	-DLLVM_ENABLE_RTTI=True \
	-DCLANG_BUILD_EXAMPLES=False \
	-DCLANG_DEFAULT_CXX_STDLIB=libc++ \
	-DCLANG_DEFAULT_LINKER=lld \
	-DCLANG_DEFAULT_RTLIB=compiler-rt \
	-DDEFAULT_SYSROOT=$PWD/sysroot \
	$PWD/src/$LLVM"
}

sysroot() {
  init 

  export PATH=$PWD/host/bin:$PATH

  mkdir -p build-sysroot-musl
  sh -c "cd build-sysroot-musl; \
	CC=$PWD/host/bin/clang \
	$PWD/src/$MUSL/configure \
	--prefix=/usr"
  make -j8 -C build-sysroot-musl
  DESTDIR=$PWD/sysroot make -C build-sysroot-musl install 

  touch $PWD/sysroot/lib/crtbeginS.o
  touch $PWD/sysroot/lib/crtendS.o

  mkdir build-sysroot-libcxx
  sh -c "cd build-sysroot-libcxx; cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_CROSSCOMPILING=True \
	-DCMAKE_INSTALL_PREFIX=$PWD/sysroot/usr \
	-DCMAKE_C_COMPILER=$PWD/host/bin/clang \
	-DCMAKE_C_FLAGS=-rtlib=compiler-rt \
	-DCMAKE_C_COMPILER_TARGET=$TARGET \
	-DCMAKE_CXX_COMPILER=$PWD/host/bin/clang++ \
	-DCMAKE_CXX_COMPILER_TARGET=$TARGET \
	-DCMAKE_EXE_LINKER_FLAGS=-L$PWD/host/lib \
	-DCMAKE_SHARED_LINKER_FLAGS=-L$PWD/build-sysroot-libcxx/lib \
	-DCMAKE_SYSROOT=$PWD/sysroot \
	-DCOMPILER_RT_BUILD_SANITIZERS=False \
	-DCOMPILER_RT_BUILD_XRAY=False \
	-DCOMPILER_RT_BUILD_LIBFUZZER=False \
	-DLIBUNWIND_USE_COMPILER_RT=True \
	-DLIBCXXABI_USE_LLVM_UNWINDER=True \
	-DLIBCXXABI_USE_COMPILER_RT=True \
	-DLIBCXXABI_HAS_CXA_THREAD_ATEXIT_IMPL=False \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS=$PWD/src/$LLVM/projects/libcxxabi/include \
	-DLIBCXX_USE_COMPILER_RT=True \
	-DLIBCXX_HAS_MUSL_LIBC=True \
	-DLIBCXX_HAS_GCC_S_LIB=False \
	-DLLVM_ENABLE_EH=True \
	-DLLVM_ENABLE_RTTI=True \
	-DLLVM_ENABLE_LIBCXX=True \
	-DLLVM_ENABLE_LLD=True \
	$PWD/src/$LLVM"

  make -j8 -C build-sysroot-libcxx install-compiler-rt
  make -j8 -C build-sysroot-libcxx install-unwind
  make -j8 -C build-sysroot-libcxx install-cxxabi
  make -j8 -C build-sysroot-libcxx install-cxx

  rm $PWD/sysroot/lib/crtbeginS.o
  rm $PWD/sysroot/lib/crtendS.o
}

sysroot_old() {
  init 

  mkdir -p build-sysroot-musl
  sh -c "cd build-sysroot-musl; \
	$PWD/src/$MUSL/configure \
	--prefix=/usr"
  make -j8 -C build-sysroot-musl
  DESTDIR=$PWD/sysroot make -C build-sysroot-musl install 

  export PATH=$PATH:$PWD/host/bin

  mkdir build-sysroot-libcxx
  sh -c "cd build-sysroot-libcxx; cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/sysroot/usr \
	-DCMAKE_SYSTEM_NAME=Linux \
	-DCMAKE_C_COMPILER=x86_64-linux-musl-gcc \
	-DCMAKE_CXX_COMPILER=x86_64-linux-musl-g++ \
	-DCMAKE_SHARED_LINKER_FLAGS=-L$PWD/build-sysroot-libcxx/lib \
	-DCOMPILER_RT_BUILD_SANITIZERS=False \
	-DCOMPILER_RT_BUILD_XRAY=False \
	-DCOMPILER_RT_BUILD_LIBFUZZER=False \
	-DLIBCXXABI_USE_LLVM_UNWINDER=True \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS=$PWD/src/$LLVM/projects/libcxxabi/include \
	-DLIBCXX_HAS_MUSL_LIBC=True \
	-DLIBCXX_HAS_GCC_S_LIB=False \
	-DLLVM_ENABLE_EH=True \
	-DLLVM_ENABLE_RTTI=True \
	$PWD/src/$LLVM"

  make -j8 -C build-sysroot-libcxx compiler-rt install-compiler-rt
  make -j8 -C build-sysroot-libcxx unwind install-unwind
  make -j8 -C build-sysroot-libcxx cxxabi install-cxxabi
  make -j8 -C build-sysroot-libcxx cxx install-cxx
}


libxml2() {
  init 

  mkdir -p build-sysroot-libxml2
  sh -c "cd build-sysroot-libxml2; \
	CC=clang \
	CFLAGS=\"-static --target=$TARGET --sysroot=$PWD/sysroot \" \
	$PWD/src/$LIBXML2/configure \
	--without-zlib \
	--without-lzma \
	--without-python \
	--prefix=$PWD/sysroot"
  make -j8 -C build-sysroot-libxml2
  make -C build-sysroot-libxml2 install
}


clean() {
  rm -rf $PWD/sysroot
  rm -rf $PWD/build-sysroot-*
  rm -rf $PWD/host
  rm -rf $PWD/build-host-*
}


distclean() {
  rm -rf src
  clean
}


all() {
  musl
  libcxx
}


$@
