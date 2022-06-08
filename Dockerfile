FROM efabless/openlane-tools:yosys-cfe940a98b08f1a5d08fb44427db155ba1f18b62-centos-7 AS yosys
# ---

FROM swift:5.6-centos7

# Setup Build Environment
RUN yum install -y --setopt=skip_missing_names_on_install=False https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm centos-release-scl
RUN yum install -y --setopt=skip_missing_names_on_install=False git curl python36 python3-pip devtoolset-8 devtoolset-8-libatomic-devel flex bison readline-devel ncurses-devel autoconf libtool gperf tcl-devel  libcurl-devel

ENV CC=/opt/rh/devtoolset-8/root/usr/bin/gcc \
    CPP=/opt/rh/devtoolset-8/root/usr/bin/cpp \
    CXX=/opt/rh/devtoolset-8/root/usr/bin/g++ \
    PATH=/opt/rh/devtoolset-8/root/usr/bin:$PATH \
    LD_LIBRARY_PATH=/opt/rh/devtoolset-8/root/usr/lib64:/opt/rh/devtoolset-8/root/usr/lib:/opt/rh/devtoolset-8/root/usr/lib64/dyninst:/opt/rh/devtoolset-8/root/usr/lib/dyninst:/opt/rh/devtoolset-8/root/usr/lib64:/opt/rh/devtoolset-8/root/usr/lib:$LD_LIBRARY_PATH

# Install Yosys
COPY --from=yosys /build /build
ENV PATH=/build/bin:$PATH

# Install git
RUN yum install -y gettext
WORKDIR /git
RUN curl -L https://github.com/git/git/tarball/e9d7761bb94f20acc98824275e317fa82436c25d/ |\
    tar -xzC . --strip-components=1 &&\
    make configure &&\
    ./configure --prefix=/build &&\
    make -j$(nproc) &&\
    make install &&\
    rm -rf *

# Install IcarusVerilog 11
WORKDIR /iverilog
RUN curl -L https://github.com/steveicarus/iverilog/archive/refs/tags/v11_0.tar.gz |\
    tar --strip-components=1 -xzC . &&\
    aclocal &&\
    autoconf &&\
    ./configure &&\
    make -j$(nproc) &&\
    make install &&\
    rm -rf *

# Install Atalanta
WORKDIR /atalanta
RUN curl -L https://github.com/hsluoyz/Atalanta/archive/12d405311c3dc9f371a9009bb5cdc8844fe34f90.tar.gz |\
    tar --strip-components=1 -xzC . &&\
    make &&\
    cp atalanta /usr/bin &&\
    rm -rf *

# Install PODEM
WORKDIR /podem
RUN curl -L http://tiger.ee.nctu.edu.tw/course/Testing2018/assignments/hw0/podem.tgz |\
    tar --strip-components=1 -xzC . &&\
    make &&\
    cp atpg /usr/bin &&\
    rm -rf *

# Install PIP dependencies
WORKDIR /
RUN python3 -m pip install --upgrade pip
COPY requirements.txt /requirements.txt
RUN python3 -m pip install --upgrade -r /requirements.txt

# Install Fault
ENV FAULT_YOSYS "yosys"
ENV PYTHON_LIBRARY /lib64/libpython3.so
WORKDIR /fault
COPY . .
RUN INSTALL_DIR=/usr/bin swift install.swift
WORKDIR /