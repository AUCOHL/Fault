FROM efabless/openlane-tools:yosys-cfe940a98b08f1a5d08fb44427db155ba1f18b62-centos-7 AS yosys
# ---

FROM swift:5.6-centos7 AS builder

# Setup Build Environment
RUN yum install -y --setopt=skip_missing_names_on_install=False https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm centos-release-scl
RUN yum install -y --setopt=skip_missing_names_on_install=False git gettext curl devtoolset-8 devtoolset-8-libatomic-devel 

ENV CC=/opt/rh/devtoolset-8/root/usr/bin/gcc \
    CPP=/opt/rh/devtoolset-8/root/usr/bin/cpp \
    CXX=/opt/rh/devtoolset-8/root/usr/bin/g++ \
    PATH=/opt/rh/devtoolset-8/root/usr/bin:$PATH \
    LD_LIBRARY_PATH=/opt/rh/devtoolset-8/root/usr/lib64:/opt/rh/devtoolset-8/root/usr/lib:/opt/rh/devtoolset-8/root/usr/lib64/dyninst:/opt/rh/devtoolset-8/root/usr/lib/dyninst:/opt/rh/devtoolset-8/root/usr/lib64:/opt/rh/devtoolset-8/root/usr/lib:$LD_LIBRARY_PATH

# Install Python3
WORKDIR /python3
RUN curl -L https://www.python.org/ftp/python/3.6.6/Python-3.6.6.tgz | tar --strip-components=1 -xzC . \
    && ./configure --enable-shared --prefix=/build \
    && make -j$(nproc) \
    && make install \
    && rm -rf /python3

# Set environment
ENV PATH=/build/bin:$PATH
ENV PYTHON_LIBRARY /build/lib/libpython3.6m.so
ENV PYTHONPATH /build/lib/pythonpath

# Install Other Dependencies
RUN yum install -y flex bison autoconf libtool gperf tcl-devel libcurl-devel openssl-devel zlib-devel

# ---

# Install Yosys
COPY --from=yosys /build /build

# Install Git (Build-only dependency)
WORKDIR /git
RUN curl -L https://github.com/git/git/tarball/e9d7761bb94f20acc98824275e317fa82436c25d/ |\
    tar -xzC . --strip-components=1 &&\
    make configure &&\
    ./configure --prefix=/usr &&\
    make -j$(nproc) &&\
    make install &&\
    rm -rf *

# Install IcarusVerilog 11
WORKDIR /iverilog
RUN curl -L https://github.com/steveicarus/iverilog/archive/refs/tags/v11_0.tar.gz |\
    tar --strip-components=1 -xzC . &&\
    aclocal &&\
    autoconf &&\
    ./configure --prefix=/build &&\
    make -j$(nproc) &&\
    make install &&\
    rm -rf *

# Python Setup
WORKDIR /
COPY requirements.txt /requirements.txt
RUN python3 -m pip install --target /build/lib/pythonpath --upgrade -r ./requirements.txt

# Copy Libraries for AppImage
RUN cp /lib64/libtinfo.so.5 /build/lib
RUN cp /lib64/libffi.so.6 /build/lib
RUN cp /lib64/libz.so.1 /build/lib
RUN cp /lib64/libreadline.so.6 /build/lib
RUN cp /lib64/libtcl8.5.so /build/lib

# Fault Setup
WORKDIR /fault
COPY . .
RUN swift build --static-swift-stdlib -c release
RUN cp /fault/.build/x86_64-unknown-linux-gnu/release/Fault /build/bin/fault
WORKDIR /
# ---

FROM centos:centos7 AS runner
COPY --from=builder /build /build
WORKDIR /test
COPY ./Tests/smoke_test.py .
COPY ./Tests/RTL/spm.v .
COPY ./Tech/osu035 ./osu035

WORKDIR /

# Set environment
ENV PATH=/build/bin:$PATH\
    PYTHON_LIBRARY=/build/lib/libpython3.6m.so\
    PYTHONPATH=/build/lib/pythonpath\
    LD_LIBRARY_PATH=/build/lib\
    FAULT_IVL_BASE=/build/lib/ivl\
    FAULT_IVERILOG=/build/bin/iverilog\
    FAULT_VVP=/build/bin/vvp

CMD [ "/bin/bash" ]