ARG ROCKY_VERSION=8
ARG QT_VERSION=6.8.3

FROM rockylinux:${ROCKY_VERSION} AS builder

ARG QT_VERSION
ARG MAKE_JOBS
ENV TOOLSET_ROOT=/opt/rh/gcc-toolset-10/root
ENV PATH=${TOOLSET_ROOT}/usr/bin:${TOOLSET_ROOT}/usr/sbin:${PATH}
ENV LD_LIBRARY_PATH=${TOOLSET_ROOT}/usr/lib64:${TOOLSET_ROOT}/usr/lib:${LD_LIBRARY_PATH}
ENV CC=${TOOLSET_ROOT}/usr/bin/gcc
ENV CXX=${TOOLSET_ROOT}/usr/bin/g++

RUN dnf -y update \
    && dnf -y install dnf-plugins-core \
    && (dnf config-manager --set-enabled powertools || dnf config-manager --set-enabled crb) \
    && dnf -y install epel-release \
    && dnf -y makecache \
    && dnf -y groupinstall "Development Tools" \
    && dnf -y install \
        gcc-toolset-10 \
        gcc-toolset-10-gcc \
        gcc-toolset-10-gcc-c++ \
        git \
        wget \
        curl \
        python3 \
        perl \
        cmake \
        ninja-build \
        pkgconfig \
        openssl-devel \
        zlib-devel \
        bzip2-devel \
        xz-devel \
        libX11-devel \
        libXext-devel \
        libXrender-devel \
        libXrandr-devel \
        libXcursor-devel \
        libXinerama-devel \
        libXi-devel \
        libXfixes-devel \
        libXdamage-devel \
        libXcomposite-devel \
        libxkbcommon-devel \
        libxkbcommon-x11-devel \
        libxcb-devel \
        xcb-util-devel \
        xcb-util-image-devel \
        xcb-util-keysyms-devel \
        xcb-util-renderutil-devel \
        xcb-util-wm-devel \
        xcb-util-cursor-devel \
        mesa-libGL-devel \
        mesa-libEGL-devel \
        mesa-libgbm-devel \
        fontconfig-devel \
        freetype-devel \
        libpng-devel \
        libjpeg-turbo-devel \
        harfbuzz-devel \
    && dnf clean all

WORKDIR /tmp
RUN curl -fsSL -o qt-src.tar.xz \
        "https://download.qt.io/official_releases/qt/6.8/${QT_VERSION}/single/qt-everywhere-src-${QT_VERSION}.tar.xz" \
    && tar -xJf qt-src.tar.xz

WORKDIR /tmp/qt-everywhere-src-${QT_VERSION}

RUN ./configure \
        -prefix /opt/qt/${QT_VERSION} \
        -opensource -confirm-license \
        -nomake tests -nomake examples \
        -submodules qtbase,qtdeclarative,qtsvg,qtshadertools \
        -qt-libpng -qt-libjpeg -qt-zlib \
        -opengl desktop \
        -xcb \
        -widgets \
        -- -DCMAKE_C_COMPILER=${TOOLSET_ROOT}/usr/bin/gcc \
           -DCMAKE_CXX_COMPILER=${TOOLSET_ROOT}/usr/bin/g++ \
    && cmake --build . --parallel ${MAKE_JOBS:-$(nproc)} \
    && cmake --install .

FROM rockylinux:${ROCKY_VERSION}

ARG QT_VERSION
ARG RUST_VERSION=stable

ENV QT_HOME=/opt/qt/${QT_VERSION}
ENV QTDIR=/opt/qt/${QT_VERSION}
ENV QT_HOST_PATH=/opt/qt/${QT_VERSION}
ENV QMAKE=/opt/qt/${QT_VERSION}/bin/qmake
ENV PATH=${QT_HOME}/bin:/opt/appimage:${PATH}
ENV LD_LIBRARY_PATH=${QT_HOME}/lib
ENV PKG_CONFIG_PATH=${QT_HOME}/lib/pkgconfig

RUN dnf -y update \
    && dnf -y install dnf-plugins-core \
    && (dnf config-manager --set-enabled powertools || dnf config-manager --set-enabled crb) \
    && dnf -y install epel-release \
    && dnf -y makecache \
    && dnf -y install \
        ca-certificates \
        git \
        wget \
        curl \
        python3 \
        perl \
        cmake \
        ninja-build \
        pkgconfig \
        openssl \
        zlib \
        bzip2 \
        xz \
        libX11 \
        libXext \
        libXrender \
        libXrandr \
        libXcursor \
        libXinerama \
        libXi \
        libXfixes \
        libXdamage \
        libXcomposite \
        libxkbcommon \
        libxkbcommon-x11 \
        libxcb \
        xcb-util \
        xcb-util-image \
        xcb-util-keysyms \
        xcb-util-renderutil \
        xcb-util-wm \
        xcb-util-cursor \
        mesa-libGL \
        mesa-libEGL \
        mesa-libgbm \
        fontconfig \
        freetype \
        libpng \
        libjpeg-turbo \
        harfbuzz \
        gcc-toolset-10 \
        gcc-toolset-10-gcc \
        gcc-toolset-10-gcc-c++ \
        libicu \
        pcre2-utf16 \
        mesa-libGL-devel \
        mesa-libGLU-devel \
        libglvnd-devel \
        libglvnd-glx \
        libglvnd-opengl \
    && dnf clean all

COPY --from=builder /opt/qt/${QT_VERSION} /opt/qt/${QT_VERSION}

# Install rust via rustup (needed for CXX-Qt builds)
RUN curl -fsSL https://sh.rustup.rs | sh -s -- -y --default-toolchain ${RUST_VERSION}
ENV PATH=/root/.cargo/bin:${PATH}

# Sanity check Qt install to ensure qmake resolves Qt paths
RUN /opt/qt/${QT_VERSION}/bin/qmake -query

# Install linuxdeploy + appimagetool + linuxdeploy-plugin-qt
ARG LINUXDEPLOY_VERSION=continuous
ARG LINUXDEPLOY_QT_VERSION=continuous
ARG APPIMAGETOOL_VERSION=continuous
ARG TARGETARCH

RUN mkdir -p /opt/appimage \
    && case "${TARGETARCH}" in \
        amd64) \
          curl -fsSL -o /opt/appimage/linuxdeploy.AppImage \
            "https://github.com/linuxdeploy/linuxdeploy/releases/download/${LINUXDEPLOY_VERSION}/linuxdeploy-x86_64.AppImage" \
          && curl -fsSL -o /opt/appimage/linuxdeploy-plugin-qt.AppImage \
            "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/${LINUXDEPLOY_QT_VERSION}/linuxdeploy-plugin-qt-x86_64.AppImage" \
          && curl -fsSL -o /opt/appimage/appimagetool.AppImage \
            "https://github.com/AppImage/AppImageKit/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-x86_64.AppImage" \
          ;; \
        arm64) \
          curl -fsSL -o /opt/appimage/linuxdeploy.AppImage \
            "https://github.com/linuxdeploy/linuxdeploy/releases/download/${LINUXDEPLOY_VERSION}/linuxdeploy-aarch64.AppImage" \
          && curl -fsSL -o /opt/appimage/linuxdeploy-plugin-qt.AppImage \
            "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/${LINUXDEPLOY_QT_VERSION}/linuxdeploy-plugin-qt-aarch64.AppImage" \
          && curl -fsSL -o /opt/appimage/appimagetool.AppImage \
            "https://github.com/AppImage/AppImageKit/releases/download/${APPIMAGETOOL_VERSION}/appimagetool-aarch64.AppImage" \
          ;; \
        *) echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
      esac \
    && chmod +x /opt/appimage/linuxdeploy.AppImage \
      /opt/appimage/linuxdeploy-plugin-qt.AppImage \
      /opt/appimage/appimagetool.AppImage

ENV LINUXDEPLOY_PLUGIN_QT=/opt/appimage/linuxdeploy-plugin-qt.AppImage

WORKDIR /workspace
