#/bin/sh

CLANG=clang-6.0
CFLAGS="-static --sysroot=$PWD/rootfs -I/usr/include"

MUSL=musl-1.1.19
TOYBOX=toybox-0.7.6
MKSH=mksh-R56c

# Generally shouldn't have to change the following
TAR=`which bsdtar`
GETSRC=`which curl` 
GETSRC="$GETSRC -o"
GIT=`which git`
PWD=`pwd`



MUSL_FILE=$MUSL.tar.gz
MUSL_HOST="https://www.musl-libc.org/releases"
TOYBOX_FILE=$TOYBOX.tar.gz
TOYBOX_HOST="https://landley.net/toybox/downloads"
MKSH_FILE=$MKSH.tgz
MKSH_HOST="http://www.mirbsd.org/MirOS/dist/mir/mksh"

mkdir -p work
mkdir -p src

mkdir -p rootfs/boot
mkdir -p rootfs/proc
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
}

function toybox {
  echo "---------------------------------------: toybox"
  if [ ! -f src/$TOYBOX_FILE ]; then
    $GETSRC src/$TOYBOX_FILE $TOYBOX_HOST/$TOYBOX_FILE
  fi

  $TAR -xf src/$TOYBOX_FILE -C work
  cp config/toybox_config work/$TOYBOX/.config
  CC=$CLANG CFLAGS=$CFLAGS make -C work/$TOYBOX oldconfig toybox
  PREFIX=$PWD/rootfs/bin make -C work/$TOYBOX install_flat
}

function mksh {
  echo "---------------------------------------: mksh"
  if [ ! -f src/$MKSH_FILE ]; then
    $GETSRC src/$MKSH_FILE $MKSH_HOST/$MKSH_FILE
  fi

  $TAR -xvf src/$MKSH_FILE -C work
  
  cd work/mksh
  cd work/mksh; CC=$CLANG CFLAGS=$CFLAGS TARGET_OS=Linux sh ./Build.sh
  cd ../..
  install -s -m 555 work/mksh/mksh rootfs/bin
  cd rootfs/bin
  ln -s mksh sh
  cd ..
}

function clean {
  rm -rf work
  rm -rf rootfs
  rm -rf $MUSL
  rm -rf $TOYBOX
  rm -rf $MKSH
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
    toybox
    mksh
  ;;
  *)
    $1
  ;;
esac
