FROM buildpack-deps:stretch-curl
MAINTAINER Manfred Touron <m@42.am> (https://github.com/moul)

# Install deps
RUN set -x; \
    dpkg --add-architecture arm64                      \
 && dpkg --add-architecture armel                      \
 && dpkg --add-architecture armhf                      \
 && dpkg --add-architecture i386                       \
 && dpkg --add-architecture mips                       \
 && dpkg --add-architecture mipsel                     \
 && dpkg --add-architecture powerpc                    \
 && dpkg --add-architecture ppc64el                    \
 && apt-get update                                     \
 && apt-get install -y -q                              \
        autoconf                                       \
        automake                                       \
        autotools-dev                                  \
        bc                                             \
        binfmt-support                                 \
        binutils-multiarch                             \
        binutils-multiarch-dev                         \
        build-essential                                \
        clang                                          \
        crossbuild-essential-arm64                     \
        crossbuild-essential-armel                     \
        crossbuild-essential-armhf                     \
        crossbuild-essential-mipsel                    \
        crossbuild-essential-ppc64el                   \
        curl                                           \
        devscripts                                     \
        gdb                                            \
        git-core                                       \
        libtool                                        \
        llvm                                           \
        mercurial                                      \
        multistrap                                     \
        patch                                          \
        python3-software-properties                    \
        software-properties-common                     \
        subversion                                     \
        wget                                           \
        xz-utils                                       \
        cmake                                          \
        qemu-user-static                               \
        ninja-build                                    \
 && apt-get clean
# FIXME: install gcc-multilib
# FIXME: add mips and powerpc architectures


# Install Windows cross-tools
RUN apt-get install -y mingw-w64 \
 && apt-get clean

# Upgrade cmake
RUN echo deb http://ftp.debian.org/debian stretch-backports main > /etc/apt/sources.list \
 && apt-get update                                     \
 && wget http://ftp.us.debian.org/debian/pool/main/r/rhash/librhash0_1.3.3-1+b2_amd64.deb \
 && apt install ./librhash0_1.3.3-1+b2_amd64.deb       \
 && apt-get -y -q install cmake-data cmake

# Install OSx cross-tools

#Build arguments
ARG osxcross_repo="tpoechtrager/osxcross"
ARG osxcross_revision="1a1733a773fe26e7b6c93b16fbf9341f22fac831"
ARG darwin_sdk_version="10.10"
ARG darwin_osx_version_min="10.6"
ARG darwin_version="14"
ARG darwin_sdk_url="https://www.dropbox.com/s/yfbesd249w10lpc/MacOSX${darwin_sdk_version}.sdk.tar.xz"

# ENV available in docker image
ENV OSXCROSS_REPO="${osxcross_repo}"                   \
    OSXCROSS_REVISION="${osxcross_revision}"           \
    DARWIN_SDK_VERSION="${darwin_sdk_version}"         \
    DARWIN_VERSION="${darwin_version}"                 \
    DARWIN_OSX_VERSION_MIN="${darwin_osx_version_min}" \
    DARWIN_SDK_URL="${darwin_sdk_url}"                 \
    CROSSBUILD=1

RUN mkdir -p "/tmp/osxcross"                                                                                   \
 && cd "/tmp/osxcross"                                                                                         \
 && curl -sLo osxcross.tar.gz "https://codeload.github.com/${OSXCROSS_REPO}/tar.gz/${OSXCROSS_REVISION}"  \
 && tar --strip=1 -xzf osxcross.tar.gz                                                                         \
 && rm -f osxcross.tar.gz                                                                                      \
 && curl -sLo tarballs/MacOSX${DARWIN_SDK_VERSION}.sdk.tar.xz                                                  \
             "${DARWIN_SDK_URL}"                \
 && yes "" | SDK_VERSION="${DARWIN_SDK_VERSION}" OSX_VERSION_MIN="${DARWIN_OSX_VERSION_MIN}" ./build.sh                               \
 && mv target /usr/osxcross                                                                                    \
 && mv tools /usr/osxcross/                                                                                    \
 && ln -sf ../tools/osxcross-macports /usr/osxcross/bin/omp                                                    \
 && ln -sf ../tools/osxcross-macports /usr/osxcross/bin/osxcross-macports                                      \
 && ln -sf ../tools/osxcross-macports /usr/osxcross/bin/osxcross-mp                                            \
 && rm -rf /tmp/osxcross                                                                                       \
 && rm -rf "/usr/osxcross/SDK/MacOSX${DARWIN_SDK_VERSION}.sdk/usr/share/man"


# Create symlinks for triples and set default CROSS_TRIPLE
ENV LINUX_TRIPLES=arm-linux-gnueabi,arm-linux-gnueabihf,aarch64-linux-gnu,mipsel-linux-gnu,powerpc64le-linux-gnu                  \
    DARWIN_TRIPLES=x86_64h-apple-darwin${DARWIN_VERSION},x86_64-apple-darwin${DARWIN_VERSION},i386-apple-darwin${DARWIN_VERSION}  \
    WINDOWS_TRIPLES=i686-w64-mingw32,x86_64-w64-mingw32                                                                           \
    CROSS_TRIPLE=x86_64-linux-gnu
COPY ./assets/osxcross-wrapper /usr/bin/osxcross-wrapper
RUN for triple in $(echo ${LINUX_TRIPLES} | tr "," " "); do                                       \
      for bin in /etc/alternatives/$triple-* /usr/bin/$triple-*; do                               \
        dest=/usr/$triple/bin/$(basename $bin | sed "s/$triple-//");                              \
        if [ ! -f "$dest" ]; then                                                                 \
          ln -s $bin "$dest";                                                                     \
        fi;                                                                                       \
      done;                                                                                       \
    done &&                                                                                       \
    for triple in $(echo ${DARWIN_TRIPLES} | tr "," " "); do                                      \
      mkdir -p /usr/$triple/bin;                                                                  \
      for bin in /usr/osxcross/bin/$triple-*; do                                                  \
        ln /usr/bin/osxcross-wrapper /usr/$triple/bin/$(basename $bin | sed "s/$triple-//");      \
      done &&                                                                                     \
      rm -f /usr/$triple/bin/clang*;                                                              \
      ln -s cc /usr/$triple/bin/gcc;                                                              \
      ln -s /usr/osxcross/SDK/MacOSX${DARWIN_SDK_VERSION}.sdk/usr /usr/$triple;  \
    done;                                                                                         \
    for triple in $(echo ${WINDOWS_TRIPLES} | tr "," " "); do                                     \
      mkdir -p /usr/$triple/bin;                                                                  \
      for bin in /etc/alternatives/$triple-* /usr/bin/$triple-*; do                               \
        dest=/usr/$triple/bin/$(basename $bin | sed "s/$triple-//");                              \
        if [ ! -f $dest ]; then                                                                   \
          ln -s $bin $dest;                                                                       \
        fi;                                                                                       \
      done;                                                                                       \
      ln -s gcc /usr/$triple/bin/cc;                                                              \
      ln -s /usr/$triple /usr/$triple;                                           \
    done
# we need to use default clang binary to avoid a bug in osxcross that recursively call himself
# with more and more parameters


# Image metadata
ENTRYPOINT ["/usr/bin/crossbuild"]
CMD ["/bin/bash"]
WORKDIR /workdir
COPY ./assets/crossbuild /usr/bin/crossbuild

RUN apt-get update

COPY ./assets/usr /usr/

ENV OPENSSL openssl-1.0.2m
#ENV OPENSSL openssl-1.1.0g
ENV WIN32 i686-w64-mingw32
ENV WIN64 x86_64-w64-mingw32
ENV OSX32 i386-apple-darwin14
ENV OSX64 x86_64-apple-darwin14
ENV OSXCROSS /usr/osxcross

ENV SDKVERSION MacOSX10.10.sdk
ENV OSXSDK ${OSXCROSS}/SDK/${SDKVERSION}

ENV MAKEOPTS -j 4
#ENV OPENSSL_CONFIG no-asm no-hw no-engine no-threads no-dso no-ssl

ENV LANG C.UTF-8

# openssl windows
RUN set -x && \
    cd /usr/src && \
    wget https://www.openssl.org/source/${OPENSSL}.tar.gz && \
    tar -xzf ${OPENSSL}.tar.gz && \
    cd ${OPENSSL} && \
    ./Configure ${OPENSSL_CONFIG} --cross-compile-prefix=${WIN32}- --prefix=/usr/${WIN32} --openssldir=/usr/${WIN32} mingw && \
    make ${MAKEOPTS} && \
    make ${MAKEOPTS} install_sw && \
    make clean && \
    ./Configure ${OPENSSL_CONFIG} --cross-compile-prefix=${WIN64}- --prefix=/usr/${WIN64} --openssldir=/usr/${WIN64} mingw64 && \
    make ${MAKEOPTS} && \
    make ${MAKEOPTS} install_sw && \
    cd .. && \
    rm -rf ${OPENSSL}

# openssl linux
RUN cd /usr/src && \
    tar -xzf ${OPENSSL}.tar.gz && \
    cd /usr/src/${OPENSSL} && \
    ./Configure ${OPENSSL_CONFIG} linux-x86_64 --debug --prefix=/usr --openssldir=/usr && \
    make ${MAKEOPTS} && \
    make ${MAKEOPTS} install_sw && \
    make clean && \
    cd .. && \
    rm -rf ${OPENSSL}

# regex windows
RUN cd /usr/src && \
    wget https://downloads.sourceforge.net/mingw/Other/UserContributed/regex/mingw-regex-2.5.1/mingw-libgnurx-2.5.1-src.tar.gz && \
    tar -xvzf mingw-libgnurx-2.5.1-src.tar.gz && \
    cd mingw-libgnurx-2.5.1 && \
    cp ../mingw32-libgnurx-Makefile.am Makefile.am && \
    cp ../mingw32-libgnurx-configure.ac configure.ac && \
    touch NEWS && \
    touch AUTHORS && \
    libtoolize --copy && \
    aclocal && \
    autoconf && \
    automake --add-missing && \
    mkdir build-win32 && \
    cd build-win32 && \
    ../configure --prefix=/usr/i686-w64-mingw32/ --host=i686-w64-mingw32 && \
    make ${MAKEOPTS} && \
    make install && \
    cd .. && \
    mkdir build-win64 && \
    cd build-win64 && \
    ../configure --prefix=/usr/x86_64-w64-mingw32/ --host=x86_64-w64-mingw32 && \
    make ${MAKEOPTS} && \
    make install && \
    cd ..

# install additional linux 64bit dependencies
RUN apt-get -y --no-install-recommends install \
        libdbus-1-dev \
        libudev-dev \
        libgl1-mesa-dev \
        libglu1-mesa-dev \
        mesa-common-dev; \
        rm -rf /var/lib/apt/lists/*
# Add this source in order to find libedit-dev.
RUN echo "deb  http://deb.debian.org/debian  stretch main" >> /etc/apt/sources.list && \
        apt-get update && \
        apt-get -y install \
        libedit-dev \
        vim


# openssl osx
RUN cd /usr/src && \
    tar -xzf ${OPENSSL}.tar.gz && \
    cd /usr/src/${OPENSSL} && \
    RANLIB=${OSXCROSS}/bin/${OSX64}-ranlib ./Configure ${OPENSSL_CONFIG} no-shared --cross-compile-prefix=${OSXCROSS}/bin/${OSX64}- --prefix=/usr/${OSX64} --openssldir=/usr/${OSX64}/ darwin64-x86_64-cc && \
    make ${MAKEOPTS} && \
    make ${MAKEOPTS} install_sw && \
    make clean


RUN cd /usr/src/${OPENSSL} && \
    rm -rf ${OSXSDK}/usr/include/openssl && \
    rm -f ${OSXSDK}/usr/lib/libcrypto.* && \
    rm -f ${OSXSDK}/usr/lib/libssl.* && \
    cp -r /usr/${OSX64}/include/openssl ${OSXSDK}/usr/include

RUN  cd ${OSXSDK}/usr/lib && \
    ${OSXCROSS}/bin/${OSX64}-libtool -static /usr/${OSX64}/lib/libcrypto.a -o ${OSXSDK}/usr/lib/libcrypto.a && \
    ${OSXCROSS}/bin/${OSX64}-libtool -static /usr/${OSX64}/lib/libssl.a -o ${OSXSDK}/usr/lib/libssl.a



