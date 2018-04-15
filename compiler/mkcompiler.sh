#/bin/sh
#
# GCC Build Options
# ../gcc-7.2.0/configure --build=x86_64-linux-musl --host=x86_64-linux-musl --target=x86_64-linux-musl --prefix=/opt/gcc-7.2.0 --disable-multilib --disable-bootstrap --disable-lto --disable-libsanitizer --enable-languages=c,c++
#

BINUTILS=binutils-2.30
GCC=gcc-7.3.0

TARGET=x86_64-linux-musl

# Generally shouldn't have to change the following
TAR=`which bsdtar`
GETSRC=`which curl` 
GETSRC="$GETSRC -o"
MAKE="make -j4"
PWD=`pwd`

GNU_HOST="https://ftp.gnu.org/gnu"
BINUTILS_FILE=$BINUTILS.tar.gz
GCC_FILE=$GCC.tar.gz

mkdir -p src
mkdir -p work

function binutils {
  echo "---------------------------------------: binutils"
  if [ ! -f src/$BINUTILS_FILE ]; then
    $GETSRC src/$BINUTILS_FILE $GNU_HOST/binutils/$BINUTILS_FILE
  fi
  $TAR -xf src/$BINUTILS_FILE -C work
  mkdir work/build-$BINUTILS
  sh -c "cd work/build-$BINUTILS; ../$BINUTILS/configure --prefix=$PWD/$BINUTILS --target=$TARGET --disable-multilib"
  $MAKE -C work/build-$BINUTILS all
  $MAKE -C work/build-$BINUTILS install
}

function gcc {
  echo "---------------------------------------: gcc"
  export PATH=$PATH:$PWD/$BINUTILS/bin
  if [ ! -f src/$GCC_FILE ]; then
    $GETSRC src/$GCC_FILE $GNU_HOST/gcc/$GCC/$GCC_FILE
  fi
  $TAR -xf src/$GCC_FILE -C work
  cd work/$GCC
  patch -p1 < ../../patches/$GCC/0002-ssp_nonshared.diff
  patch -p1 < ../../patches/$GCC/0004-posix_memalign.diff
  patch -p1 < ../../patches/$GCC/0005-cilkrts.diff
  patch -p1 < ../../patches/$GCC/0006-libatomic-test-fix.diff
  patch -p1 < ../../patches/$GCC/0007-libgomp-test-fix.diff
  patch -p1 < ../../patches/$GCC/0008-libitm-test-fix.diff
  patch -p1 < ../../patches/$GCC/0009-libvtv-test-fix.diff
  ./contrib/download_prerequisites
  cd ../..
  mkdir work/build-$GCC
  sh -c "cd work/build-$GCC; ../$GCC/configure --prefix=$PWD/$GCC --target=$TARGET --disable-multilib --disable-bootstrap --disable-lto --disable-libsanitizer --enable-languages=c,c++"
  $MAKE -C work/build-$GCC all-gcc
  $MAKE -C work/build-$GCC install-gcc
}

function clean {
  rm -rf work
  rm -rf $BINUTILS
  rm -rf $GCC
}

case $1 in
  "")
    echo "You must supply a paramter."
    echo "  all      - build everything"
    echo "  clean    - clean"
  ;; 
  all)
    binutils 
    gcc
  ;;
  *)
    $1
  ;;
esac
