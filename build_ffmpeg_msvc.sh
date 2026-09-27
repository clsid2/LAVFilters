#!/bin/sh

# build_ffmpeg_msvc.sh [x86|x64] [release] [quick] [clang]
#
# Builds ffmpeg with the MSVC toolchain, with cl or (given "clang") clang targeting the
# MSVC ABI. Run from a Visual Studio developer prompt for the right architecture.
# The external libraries ffmpeg links against are built from msvc\libs when missing.

arch=x86
archdir=Win32
archincdir=32
triple=i686-pc-windows-msvc
clean_build=true
debug=true
compiler=cl

for opt in "$@"
do
    case "$opt" in
    x86)
            ;;
    x64 | amd64)
            arch=x86_64
            archdir=x64
            archincdir=64
            triple=x86_64-pc-windows-msvc
            ;;
    quick)
            clean_build=false
            ;;
    release)
            debug=false
            ;;
    clang)
            compiler=clang
            ;;
    *)
            echo "Unknown Option $opt"
            exit 1
    esac
done

if $debug ; then
  bindir=bin_${archdir}d
  libconfig=Debug
else
  bindir=bin_${archdir}
  libconfig=Release
fi

# C:/... form of a path, understood by cl, clang, link and pkg-config alike
winpath() (
  cygpath -m "$1"
)

make_dirs() (
  mkdir -p bin_${archdir}d/lib
  mkdir -p bin_${archdir}/lib
  mkdir -p ${bindir}/lib/pkgconfig
)

# The MinGW archives under thirdparty cannot be linked by link.exe, so the libraries
# come from the projects in msvc\libs, built into ${bindir}/lib when not there yet.
build_libs() (
  for proj in zlib/zlib:zlib dav1d/dav1d:dav1d libxml2/libxml2:xml2 speex/speex:speex bzip2/bzip2:bz2 \
              opencore-amr/opencore-amrnb:opencore-amrnb opencore-amr/opencore-amrwb:opencore-amrwb ; do
    vcxproj=msvc/libs/${proj%%:*}.vcxproj
    lib=${bindir}/lib/${proj##*:}.lib
    if [ ! -f "$lib" ]; then
      echo "Building ${proj##*:}.lib..."
      MSBuild.exe "$vcxproj" -nologo -m -v:q -p:Configuration=${libconfig} -p:Platform=${archdir} || return 1
    fi
  done
)

# pkg-config files for the two libraries configure only accepts through pkg-config
write_pkgconfig() (
  libdir=$(winpath "$PWD/${bindir}/lib")
  msvc=$(winpath "$PWD/msvc/libs")
  dav1d_ver=$(sed -n "s/^ *version: '\([0-9.]*\)'.*/\1/p" msvc/libs/dav1d/dav1d/meson.build | head -1)
  xml2_ver=$(sed -n 's/^#define LIBXML_DOTTED_VERSION "\(.*\)"/\1/p' msvc/libs/libxml2/include/libxml/xmlversion.h)
  printf 'Name: dav1d\nDescription: dav1d\nVersion: %s\nLibs: -L%s -ldav1d\nCflags: -I%s/dav1d/dav1d/include\n' \
    "$dav1d_ver" "$libdir" "$msvc" > ${bindir}/lib/pkgconfig/dav1d.pc
  printf 'Name: libxml-2.0\nDescription: libxml2\nVersion: %s\nLibs: -L%s -lxml2\nCflags: -I%s/libxml2/include -I%s/libxml2/libxml2/include -DLIBXML_STATIC\n' \
    "$xml2_ver" "$libdir" "$msvc" "$msvc" > ${bindir}/lib/pkgconfig/libxml-2.0.pc
)

copy_libs() (
  cp -u lib*/*-lav-*.dll ../${bindir}
  cp -u lib*/*-lav-*.pdb ../${bindir}
  cp -u lib*/*.lib ../${bindir}/lib
)

clean() (
  make distclean > /dev/null 2>&1
)

configure() (
  OPTIONS="
    --enable-shared                 \
    --disable-static                \
    --enable-gpl                    \
    --enable-version3               \
    --disable-autodetect            \
    --enable-w32threads             \
    --disable-demuxer=matroska      \
    --disable-filters               \
    --enable-filter=scale,yadif,w3fdif,bwdif \
    --disable-protocol=async,cache,concat,httpproxy,icecast,md5,subfile \
    --disable-muxers                \
    --enable-muxer=spdif            \
    --disable-bsfs                  \
    --enable-bsf=extract_extradata,dovi_split \
    --disable-avdevice              \
    --disable-encoders              \
    --disable-devices               \
    --disable-programs              \
    --disable-doc                   \
    --enable-avisynth               \
    --enable-d3d11va                \
    --enable-dxva2                  \
    --enable-schannel               \
    --enable-zlib                   \
    --enable-bzlib                  \
    --enable-libdav1d               \
    --enable-libspeex               \
    --enable-libopencore-amrnb      \
    --enable-libopencore-amrwb      \
    --enable-libxml2                \
    --build-suffix=-lav             \
    --disable-stripping             \
    --arch=${arch}"

  libdir=$(winpath "$PWD/../${bindir}/lib")
  msvc=$(winpath "$PWD/../msvc/libs")
  EXTRA_CFLAGS="-D_WIN32_WINNT=0x0601 -DWINVER=0x0601 -I../thirdparty/$archincdir/include/"
  EXTRA_CFLAGS="${EXTRA_CFLAGS} -I$msvc/zlib/zlib -I$msvc/speex/include -I$msvc/speex/speex/include -I$msvc/opencore-amr/include -I$msvc/bzip2/bzip2"
  EXTRA_LDFLAGS="-LIBPATH:$libdir -NODEFAULTLIB:libcmt"

  if [ "$compiler" = clang ]; then
    # clang's GNU-style driver targeting the MSVC ABI; -fms-runtime-lib is its spelling of -MD/-MDd
    CC_OPT="--cc=clang --target=${triple}"
    if $debug ; then
      OPTIONS="${OPTIONS} --enable-debug --disable-optimizations"
      EXTRA_CFLAGS="${EXTRA_CFLAGS} -fms-runtime-lib=dll_dbg"
    else
      OPTIONS="${OPTIONS} --disable-debug"
      EXTRA_CFLAGS="${EXTRA_CFLAGS} -fms-runtime-lib=dll"
    fi
    sh configure --toolchain=msvc "${CC_OPT}" --extra-cflags="${EXTRA_CFLAGS}" --extra-ldflags="${EXTRA_LDFLAGS}" ${OPTIONS}
  else
    EXTRA_CFLAGS="${EXTRA_CFLAGS} -Zo -GS-"
    if $debug ; then
      OPTIONS="${OPTIONS} --enable-debug --disable-optimizations"
      EXTRA_CFLAGS="${EXTRA_CFLAGS} -MDd"
    else
      OPTIONS="${OPTIONS} --disable-debug"
      EXTRA_CFLAGS="${EXTRA_CFLAGS} -MD"
    fi
    sh configure --toolchain=msvc --extra-cflags="${EXTRA_CFLAGS}" --extra-ldflags="${EXTRA_LDFLAGS}" ${OPTIONS}
  fi
)

# Two HEVC files select their instruction set with "#pragma GCC target", which clang
# ignores. Build them first with the features given explicitly; make then leaves them alone.
build_intrinsics() (
  for f in libavcodec/x86/hevc/intra_intrinsic.o libavcodec/x86/hevc/idct_intrinsic.o ; do
    cmd=$(make -n V=1 "$f" 2>/dev/null | grep '^clang ' | tail -1)
    if [ -n "$cmd" ]; then
      mkdir -p "$(dirname "$f")"
      eval "$(echo "$cmd" | sed 's/ -c / -mssse3 -msse4.1 -c /')" || return 1
    fi
  done
)

build() (
  if [ "$compiler" = clang ]; then
    build_intrinsics || return 1
  fi
  make -j$NUMBER_OF_PROCESSORS
)

if [ "$compiler" = clang ]; then
  # prefer the clang Visual Studio ships (VsDevCmd sets VCINSTALLDIR); another clang on PATH may be older
  if [ -n "$VCINSTALLDIR" ] && [ -x "$(cygpath -u "$VCINSTALLDIR")Tools/Llvm/x64/bin/clang.exe" ]; then
    PATH="$(cygpath -u "$VCINSTALLDIR")Tools/Llvm/x64/bin:$PATH"
  fi
  command -v clang > /dev/null || { echo "clang not found; install the Visual Studio component \"C++ Clang Compiler for Windows\""; exit 1; }
fi

# ffmpeg builds with GNU make and probes the libraries with pkg-config, so a POSIX
# environment (MSYS2) is still needed alongside the Visual Studio developer prompt.
missing=""
for tool in make pkg-config nasm cygpath MSBuild.exe ; do
  command -v $tool > /dev/null 2>&1 || missing="$missing $tool"
done
[ "$compiler" = cl ] && { command -v cl > /dev/null 2>&1 || missing="$missing cl"; }
if [ -n "$missing" ]; then
  echo "Not found on PATH:$missing"
  echo "Run from a Visual Studio developer prompt for the target architecture, with MSYS2 (make, pkg-config) and nasm on PATH."
  exit 1
fi

echo Building ffmpeg in MSVC ${libconfig} config with ${compiler}...

make_dirs
build_libs || exit 1
write_pkgconfig
export PKG_CONFIG_PATH="$PWD/${bindir}/lib/pkgconfig"

cd ffmpeg

if $clean_build ; then
    clean

    ## run configure, redirect to file because of a msys bug
    configure > ffbuild/config.out 2>&1
    CONFIGRETVAL=$?

    ## show configure output
    cat ffbuild/config.out
fi

## Only if configure succeeded, actually build
RETVAL=1
if ! $clean_build || [ ${CONFIGRETVAL} -eq 0 ]; then
  build &&
  copy_libs &&
  RETVAL=0
fi

cd ..
exit ${RETVAL}
