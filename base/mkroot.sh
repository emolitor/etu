#/bin/sh

CLANG=clang-6.0
TARGET=x86_64-linux-musl

MUSL=musl-1.1.19
ZLIB=zlib-1.2.11
LIBARCHIVE=libarchive-3.3.2
BZIP2=bzip2-1.0.6
TOYBOX=toybox-0.7.6
MKSH=mksh-R56c
PERL=perl-5.26.2
PERL_CROSS=perl-cross-1.1.9



# Generally shouldn't have to change the following
TAR=`which bsdtar`
GETSRC=`which curl` 
GETSRC="$GETSRC -L -o"
GIT=`which git`
PWD=`pwd`


MUSL_FILE=$MUSL.tar.gz
MUSL_HOST="https://www.musl-libc.org/releases"
ZLIB_FILE=$ZLIB.tar.gz
ZLIB_HOST="https://zlib.net"
LIBARCHIVE_FILE=$LIBARCHIVE.tar.gz
LIBARCHIVE_HOST="https://www.libarchive.org/downloads"
BZIP2_FILE=$BZIP2.tar.gz
BZIP2_HOST="http://www.bzip.org/1.0.6"
TOYBOX_FILE=$TOYBOX.tar.gz
TOYBOX_HOST="https://landley.net/toybox/downloads"
MKSH_FILE=$MKSH.tgz
MKSH_HOST="http://www.mirbsd.org/MirOS/dist/mir/mksh"
PERL_FILE=$PERL.tar.gz
PERL_HOST="https://www.cpan.org/src/5.0"
PERL_CROSS_FILE=$PERL_CROSS.tar.gz
PERL_CROSS_HOST="https://github.com/arsv/perl-cross/releases/download/1.1.9"

mkdir -p work
mkdir -p src

mkdir -p rootfs/boot
mkdir -p rootfs/dev
mkdir -p rootfs/etc
mkdir -p rootfs/proc

function musl {
  echo "---------------------------------------: musl"
  if [ ! -f src/$MUSL_FILE ]; then
    $GETSRC src/$MUSL_FILE $MUSL_HOST/$MUSL_FILE
  fi

  $TAR -xf src/$MUSL_FILE -C work
  mkdir work/build-$MUSL
  sh -c "cd work/build-$MUSL; CC=$CLANG ../$MUSL/configure --prefix=/usr"
  make -j 4 -C work/build-$MUSL
  DESTDIR=$PWD/rootfs make -C work/build-$MUSL install

  # Setup cross compile linker helper
  cp rootfs/usr/bin/ld.musl-clang rootfs/usr/bin/ld.musl-clang-x
  sed -i "s?libc_lib=\"/usr/lib\"?libc_lib=\"$PWD/rootfs/usr/lib\"?" rootfs/usr/bin/ld.musl-clang-x
  chmod a+x rootfs/usr/bin/ld.musl-clang-x

  # Setup cross compile helper
  cp -P rootfs/usr/bin/musl-clang rootfs/usr/bin/musl-clang-x
  sed -i "s?libc=\"/usr\"?libc=\"$PWD/rootfs/usr\"?" rootfs/usr/bin/musl-clang-x
  sed -i "s?libc_lib=\"/usr/lib\"?libc_lib=\"$PWD/rootfs/usr/lib\"?" rootfs/usr/bin/musl-clang-x
  sed -i "s?libc_inc=\"/usr/include\"?libc_inc=\"$PWD/rootfs/usr/include\"?" rootfs/usr/bin/musl-clang-x
  chmod a+x rootfs/usr/bin/musl-clang-x
}

function zlib {
  echo "---------------------------------------: zlib"
  if [ ! -f src/$ZLIB_FILE ]; then
    $GETSRC src/$ZLIB_FILE $ZLIB_HOST/$ZLIB_FILE
  fi

  $TAR -xf src/$ZLIB_FILE -C work
  mkdir work/build-$ZLIB

  sh -c "cd work/build-$ZLIB; CC=$PWD/rootfs/usr/bin/musl-clang-x ../$ZLIB/configure --prefix=$PWD/rootfs/usr"
  make -j 4 -C work/build-$ZLIB
  make -C work/build-$ZLIB install
}

function libarchive {
  echo "---------------------------------------: libarchive"
  if [ ! -f src/$LIBARCHIVE_FILE ]; then
    $GETSRC src/$LIBARCHIVE_FILE $LIBARCHIVE_HOST/$LIBARCHIVE_FILE
  fi

  $TAR -xf src/$LIBARCHIVE_FILE -C work
  mkdir work/build-$LIBARCHIVE
  sh -c "cd work/build-$LIBARCHIVE; CC=$PWD/rootfs/usr/bin/musl-clang-x ../$LIBARCHIVE/configure --prefix=$PWD/rootfs/usr --without-xml2"
  make -j4 -C work/build-$LIBARCHIVE
  make -C work/build-$LIBARCHIVE install
}

function bzip2 {
  echo "---------------------------------------: libarchive"
  if [ ! -f src/$BZIP2_FILE ]; then
    $GETSRC src/$BZIP2_FILE $BZIP2_HOST/$BZIP2_FILE
  fi

  $TAR -xf src/$BZIP2_FILE -C work
  sed -i "s/CC=gcc/CC?=gcc/" work/$BZIP2/Makefile
  sed -i "s@PREFIX=/usr/local@PREFIX?=/usr/local@" work/$BZIP2/Makefile

  sh -c "cd work/$BZIP2; CC=$PWD/rootfs/usr/bin/musl-clang-x PREFIX=$PWD/rootfs/usr make all install"
}

function toybox {
  echo "---------------------------------------: toybox"
  if [ ! -f src/$TOYBOX_FILE ]; then
    $GETSRC src/$TOYBOX_FILE $TOYBOX_HOST/$TOYBOX_FILE
  fi

  CFLAGS="-static --sysroot=$PWD/rootfs -I/usr/include"

  $TAR -xf src/$TOYBOX_FILE -C work
  cp config/toybox_config work/$TOYBOX/.config
  CC=$CLANG CFLAGS=-$CFLAGS make -C work/$TOYBOX oldconfig toybox
  PREFIX=$PWD/rootfs/bin make -C work/$TOYBOX install_flat

  CFLAGS=""
}

function mksh {
  echo "---------------------------------------: mksh"
  if [ ! -f src/$MKSH_FILE ]; then
    $GETSRC src/$MKSH_FILE $MKSH_HOST/$MKSH_FILE
  fi

  $TAR -xf src/$MKSH_FILE -C work
  
  CFLAGS="-static --sysroot=$PWD/rootfs -I/usr/include"

  cd work/mksh
  cd work/mksh; CC=$CLANG CFLAGS=$CFLAGS TARGET_OS=Linux sh ./Build.sh
  cd ../..
  install -s -m 555 work/mksh/mksh rootfs/bin
  cd rootfs/bin
  ln -s mksh sh
  cd ..
  CFLAGS=""
}

function perl {
  echo "---------------------------------------: perl"
  if [ ! -f src/$PERL_FILE ]; then
    $GETSRC src/$PERL_FILE $PERL_HOST/$PERL_FILE
  fi

  if [ ! -f src/$PERL_CROSS_FILE ]; then
    $GETSRC src/$PERL_CROSS_FILE $PERL_CROSS_HOST/$PERL_CROSS_FILE
  fi

  $TAR -xf src/$PERL_FILE -C work
  $TAR -xf src/$PERL_CROSS_FILE -C work/$PERL --strip 1

  #sh -c "cd work/$PERL; CC=$PWD/rootfs/usr/bin/musl-clang-x CFLAGS=\"-I $PWD/rootfs/usr/include\" ../$PERL/configure --target=$TARGET --sysroot=$PWD/rootfs --with-ranlib=llvm-ranlib --with-ar=llvm-ar --with-objdump=llvm-objdump --host-cc=clang --host-ranlib=llvm-ranlib --host-ar=llvm-ar --host-objdump=llvm-objdump"
  sh -c "cd work/$PERL; ../$PERL/configure --target=$TARGET --with-cc=musl-clang --with-ranlib=llvm-ranlib --with-ar=llvm-ar --with-objdump=llvm-objdump"

  make -C work/$PERL
  make -C work/$PERL DESTDIR=$PWD/rootfs/opt install 
}


function clean {
  rm -rf work
  rm -rf rootfs
  rm -rf $MUSL
}

case $1 in
  "")
    echo "You must supply a paramter."
    echo "  all      - build everything"
    echo "  package  - build just package"
    echo "  clean    - clean"
  ;; 
  all)
    musl
    zlib
    bzip2
    libarchive
    toybox
    mksh
  ;;
  *)
    $1
  ;;
esac
