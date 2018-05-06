#!/bin/sh

MUSL_VERSION=1.1.19
LIBICU_VERSION=61.1
LIBXML2_VERSION=2.9.8
LLVM_VERSION=6.0.0

# You shouldn't have to change anything below here
TARGET=x86_64-pc-linux-musl

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
    echo "OUTPUT=$PWD/host" >> $PWD/src/musl-cross-make/config.mak
    echo "COMMON_CONFIG+=CFLAGS=\"-g0 -Os\" CXXFLAGS=\"-g0 -Os\" LDFLAGS=\"-s\"" >> $PWD/src/musl-cross-make/config.mak

    sh -c "cd src; curl -L -O $MUSL_URL/$MUSL_FILE"
#    sh -c "cd src; curl -L -O $LIBICU_URL/$LIBICU_FILE"
    sh -c "cd src; curl -L -O $LIBXML2_URL/$LIBXML2_FILE"
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

    sh -c "cd src; bsdtar -xf $LIBXML2_FILE"

    mkdir -p src/$LIBUNWIND
    bsdtar -xf src/$LIBUNWIND_FILE -C src/$LIBUNWIND --strip 1
    mkdir -p src/$LIBCXXABI
    bsdtar -xf src/$LIBCXXABI_FILE -C src/$LIBCXXABI --strip 1
    mkdir -p src/$LIBCXX
    bsdtar -xf src/$LIBCXX_FILE -C src/$LIBCXX --strip 1

    mkdir -p src/$LLVM
    bsdtar -xf src/$LLVM_FILE -C src/$LLVM --strip 1
    #mkdir -p src/$LLVM/projects/libunwind
    #bsdtar -xf src/$LIBUNWIND_FILE -C src/$LLVM/projects/libunwind --strip 1
    #mkdir -p src/$LLVM/projects/libcxxabi
    #bsdtar -xf src/$LIBCXXABI_FILE -C src/$LLVM/projects/libcxxabi --strip 1
    #mkdir -p src/$LLVM/projects/libcxx
    #bsdtar -xf src/$LIBCXX_FILE -C src/$LLVM/projects/libcxx --strip 1
    mkdir -p src/$LLVM/projects/compiler-rt
    bsdtar -xf src/$COMPILER_RT_FILE -C src/$LLVM/projects/compiler-rt --strip 1
    mkdir -p src/$LLVM/tools/clang
    bsdtar -xf src/$CFE_FILE -C src/$LLVM/tools/clang --strip 1
    #mkdir -p src/$LLVM/tools/lld
    #bsdtar -xf src/$LLD_FILE -C src/$LLVM/tools/lld --strip 1
  fi
}


host_gcc() {
    make -j12 -C $PWD/src/musl-cross-make
    make -C $PWD/src/musl-cross-make install
}


sysroot() {
  init 

#  mkdir -p build-sysroot-musl
#  sh -c "cd build-sysroot-musl; \
#	CC=clang \
#	$PWD/src/$MUSL/configure \
#	--prefix=/"
#  make -j8 -C build-sysroot-musl
#  DESTDIR=$PWD/sysroot make -C build-sysroot-musl install 
#	CC=clang CFLAGS=\"--sysroot=$PWD/sysroot\" \
#	CXX=clang++ \
#	cmake \

  mkdir build-sysroot-libunwind
  sh -c "cd build-sysroot-libunwind; cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/sysroot \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_C_FLAGS=--sysroot=$PWD/sysroot \
	-DCMAKE_CXX_COMPILER=clang++ \
	-DCMAKE_INSTALL_PREFIX=$PWD/sysroot \
	-DLLVM_PATH=$PWD/src/$LLVM \
	$PWD/src/$LIBUNWIND"

#	-DLIBUNWIND_ENABLE_SHARED=False \

  make -j8 -C build-sysroot-libunwind unwind 

  mkdir build-sysroot-libcxxabi
  sh -c "cd build-sysroot-libcxxabi; cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/sysroot \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_C_FLAGS=--sysroot=$PWD/sysroot \
	-DCMAKE_CXX_COMPILER=clang++ \
	-DCMAKE_SHARED_LINKER_FLAGS=\"-L$PWD/sysroot/lib -L$PWD/build-sysroot-libunwind/lib\" \
	-DLIBCXXABI_USE_LLVM_UNWINDER=True \
	-DLIBCXXABI_ENABLE_STATIC_UNWINDER=True \
	-DLIBCXXABI_LIBUNWIND_PATH=$PWD/src/$LIBUNWIND \
	-DLIBCXXABI_LIBCXX_INCLUDES=$PWD/src/$LIBCXX/include \
	$PWD/src/$LIBCXXABI"
  make -j8 -C build-sysroot-libcxx cxxabi 

  mkdir build-sysroot-libcxx
  sh -c "cd build-sysroot-libcxx; cmake \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/sysroot \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_C_FLAGS=--sysroot=$PWD/sysroot \
	-DCMAKE_CXX_COMPILER=clang++ \
	-DCMAKE_SHARED_LINKER_FLAGS=\"-L$PWD/sysroot/lib -L$PWD/build-sysroot-libcxxabi/lib\" \
	-DLIBCXX_CXX_ABI=libcxxabi \
	-DLIBCXX_CXX_ABI_INCLUDE_PATHS=$PWD/src/$LIBCXXABI/include \
	-DLIBCXX_HAS_MUSL_LIBC=True \
	-DLIBCXX_HAS_GCC_S_LIB=False \
	$PWD/src/$LIBCXX"
exit
  make -j8 -C build-sysroot-libcxx cxx install-cxx
}


host() {
  init
  
  mkdir build-host-clang
  sh -c "cd build-host-clang; cmake -GNinja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/host \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_CXX_COMPILER=clang++ \
	-DDEFAULT_SYSROOT=$PWD/sysroot \
	-DCLANG_DEFAULT_CXX_STDLIB=libc++ \
	-DCLANG_DEFAULT_LINKER=lld \
	-DCLANG_DEFAULT_RTLIB=compiler-rt \
	-DLLVM_DEFAULT_TARGET_TRIPLE=$TARGET \
	-DLLVM_ENABLE_LLD=True \
	$PWD/src/$LLVM"
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
