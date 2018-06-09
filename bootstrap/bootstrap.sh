#!/bin/sh

MUSL_VERSION=1.1.19
LIBICU_VERSION=61.1
LIBXML2_VERSION=2.9.8
LLVM_VERSION=6.0.0

ETU_CSU_REPO="https://github.com/emolitor/etu-csu"

# You shouldn't have to change anything below here
TARGET=x86_64-linux-musl
HOST=`uname -s`

TAR=`which tar`

BMAKE=bmake
BMAKE_FILE=$BMAKE.tar.gz
BMAKE_URL='http://www.crufty.net/ftp/pub/sjg'

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

    sh -c "cd src; git clone $ETU_CSU_REPO"

    sh -c "cd src; curl -L -O $BMAKE_URL/$BMAKE_FILE"
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

    sh -c "cd src; $TAR -xf $BMAKE_FILE"

    sh -c "cd src; $TAR -xf $MUSL_FILE"

#    mkdir -p src/$LIBICU
#    $TAR -xf src/$LIBICU_FILE -C src/$LIBICU --strip 1

    sh -c "cd src; $TAR -xf $LIBXML2_FILE"

    mkdir -p src/$LLVM
    $TAR -xf src/$LLVM_FILE -C src/$LLVM --strip 1
    mkdir -p src/$LLVM/projects/libunwind
    $TAR -xf src/$LIBUNWIND_FILE -C src/$LLVM/projects/libunwind --strip 1
    mkdir -p src/$LLVM/projects/libcxxabi
    $TAR -xf src/$LIBCXXABI_FILE -C src/$LLVM/projects/libcxxabi --strip 1
    mkdir -p src/$LLVM/projects/libcxx
    $TAR -xf src/$LIBCXX_FILE -C src/$LLVM/projects/libcxx --strip 1
    mkdir -p src/$LLVM/projects/compiler-rt
    $TAR -xf src/$COMPILER_RT_FILE -C src/$LLVM/projects/compiler-rt --strip 1
    mkdir -p src/$LLVM/tools/clang
    $TAR -xf src/$CFE_FILE -C src/$LLVM/tools/clang --strip 1
    mkdir -p src/$LLVM/tools/lld
    $TAR -xf src/$LLD_FILE -C src/$LLVM/tools/lld --strip 1
  fi
}


host() {
  init 

  mkdir build-host-clang
  sh -c "cd build-host-clang; cmake -G Ninja \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_INSTALL_PREFIX=$PWD/host \
	-DLIBCXX_HAS_MUSL_LIBC=False \
	-DCOMPILER_RT_BUILD_LIBFUZZER=False \
	-DCOMPILER_RT_BUILD_SANITIZERS=False \
	-DCOMPILER_RT_BUILD_XRAY=False \
	$PWD/src/$LLVM"

  ninja -C build-host-clang 
  ninja -C build-host-clang install

  mkdir build-host-bmake
  sh -c "cd build-host-bmake; \
         CC=$PWD/host/bin/clang \
         $PWD/src/bmake/configure --prefix=$PWD/host"
  sh -c "cd build-host-bmake; \
         sh make-bootstrap.sh"
  sh -c "cd build-host-bmake; \
         ./bmake -m $PWD/src/bmake/mk install"
}


sysroot() {
  init

  if [ $HOST = "Darwin" ]; then
	CROSS_COMPILE="g"
  fi

  mkdir -p build-sysroot-musl
  sh -c "cd build-sysroot-musl; \
	CROSS_COMPILE=$CROSS_COMPILE \
	CFLAGS=\"--target=$TARGET -fuse-ld=lld\" \
	CC=$PWD/host/bin/clang \
	$PWD/src/$MUSL/configure \
	--prefix=/"
  make -j8 -C build-sysroot-musl 
  DESTDIR=$PWD/sysroot make -C build-sysroot-musl install 

  sh -c "cd src/etu-csu; BMAKE=$PWD/host/bin/bmake \
	./build.sh -m $PWD/host/share/mk"
  mv $PWD/src/etu-csu/output/x86_64/* $PWD/sysroot/lib
  sh -c "cd $PWD/sysroot/lib; ln -s crtbegin.o crtbeginT.o"
  sh -c "cd $PWD/sysroot/lib; ln -s crtend.o crtendS.o"
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
  host
  sysroot
}


$@
