#!/usr/bin/env bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
exec 4>&1; export BASH_XTRACEFD=4; set -x
# make errors fatal
set -e
# complain about unset env variables
set -u

OPENJPEG_VERSION="1.4"
OPENJPEG_SOURCE_DIR="openjpeg_v1_4_sources_r697"

if [ -z "$AUTOBUILD" ] ; then 
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    autobuild="$(cygpath -u $AUTOBUILD)"
else
    autobuild="$AUTOBUILD"
fi

stage="$(pwd)/stage"

# load autobuild provided shell functions and variables
source_environment_tempfile="$stage/source_environment.sh"
"$autobuild" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

build=${AUTOBUILD_BUILD_ID:=0}
echo "${OPENJPEG_VERSION}.${build}" > "${stage}/VERSION.txt"

pushd "$OPENJPEG_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in
        windows*)
            load_vsvars

            if [ "${AUTOBUILD_WIN_VSPLATFORM}" = "Win32" ] ; then
                cmake . -G"Visual Studio 15" -DCMAKE_INSTALL_PREFIX=$stage
            else
                cmake . -G"Visual Studio 15 Win64" -DCMAKE_INSTALL_PREFIX=$stage -DND_WIN64_BUILD=On
            fi

            build_sln "OPENJPEG.sln" "Release|$AUTOBUILD_WIN_VSPLATFORM"
            build_sln "OPENJPEG.sln" "Debug|$AUTOBUILD_WIN_VSPLATFORM"

            
            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp bin/Release/openjpeg{.dll,.lib} "$stage/lib/release"
            cp bin/Debug/openjpeg.dll "$stage/lib/debug/openjpegd.dll"
            cp bin/Debug/openjpeg.lib "$stage/lib/debug/openjpegd.lib"
            cp bin/Debug/openjpeg.pdb "$stage/lib/debug/openjpegd.pdb"
            mkdir -p "$stage/include/openjpeg"
            cp libopenjpeg/openjpeg.h "$stage/include/openjpeg"
        ;;

        darwin*)
            cmake . -GXcode -D'CMAKE_OSX_ARCHITECTURES:STRING=i386;x86_64' \
                -D'BUILD_SHARED_LIBS:bool=off' -D'BUILD_CODEC:bool=off' \
                -DCMAKE_INSTALL_PREFIX=$stage -DCMAKE_OSX_DEPLOYMENT_TARGET=10.7 \
                -DCMAKE_OSX_SYSROOT=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.9.sdk
            xcodebuild -configuration Release -target openjpeg -project openjpeg.xcodeproj
            xcodebuild -configuration Release -target install -project openjpeg.xcodeproj
                mkdir -p "$stage/lib/release"
            cp "$stage/lib/libopenjpeg.a" "$stage/lib/release/libopenjpeg.a"
                mkdir -p "$stage/include/openjpeg"
            cp "$stage/include/openjpeg-$OPENJPEG_VERSION/openjpeg.h" "$stage/include/openjpeg"

        ;;
        linux*)
            if [ ${AUTOBUILD_ADDRSIZE} = 32 ] ; then
                gcc_flags = "-m32"
            else
                gcc_flags = "-m64 -fPIC"
            fi

            test -d "${stage}/include" && rm -rf "${stage}/include"
            autoreconf -i
            CFLAGS="$gcc_flags" CPPFLAGS="$gcc_flags" LDFLAGS="$gcc_flags" ./configure --target=i686-linux-gnu --prefix="$stage" --enable-png=no --enable-lcms1=no --enable-lcms2=no --enable-tiff=no --libdir="${stage}/lib"
            make
            make install

            mv "$stage/include/openjpeg-$OPENJPEG_VERSION" "$stage/include/openjpeg"

            mv "$stage/lib" "$stage/release"
            mkdir -p "$stage/lib"
            mv "$stage/release" "$stage/lib"
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    cp LICENSE "$stage/LICENSES/openjpeg.txt"
popd
