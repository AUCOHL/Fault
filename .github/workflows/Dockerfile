FROM rockylinux:8 AS build
RUN dnf groupinstall -y "Development Tools"
RUN dnf install -y flex bison
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN dnf install -y openssl-devel pkgconfig
RUN cargo install quaigh

RUN dnf --enablerepo=powertools install -y gperf
RUN mkdir -p /iverilog
WORKDIR /iverilog_build
RUN curl -L https://github.com/steveicarus/iverilog/archive/ea26587b5ef485f2ca82a3e4364e58ec3307240f.tar.gz | \
    tar -xzvC . --strip-components=1 && \
    sh autoconf.sh && \
    ./configure --prefix=/iverilog && \
    make -j$(nproc) && \
    make install

RUN dnf install -y readline-devel tcl-devel libffi-devel gcc-toolset-14
RUN mkdir -p /yosys
WORKDIR /yosys_build
ENV CC=/opt/rh/gcc-toolset-14/root/usr/bin/gcc \
    CPP=/opt/rh/gcc-toolset-14/root/usr/bin/cpp \
    CXX=/opt/rh/gcc-toolset-14/root/usr/bin/g++ \
    PATH=/opt/rh/gcc-toolset-14/root/usr/bin:$PATH \
    LD_LIBRARY_PATH=/opt/rh/gcc-toolset-14/root/usr/lib64:/opt/rh/gcc-toolset-14/root/usr/lib:/opt/rh/gcc-toolset-14/root/usr/lib64/dyninst:/opt/rh/gcc-toolset-14/root/usr/lib/dyninst:/opt/rh/gcc-toolset-14/root/usr/lib64:/opt/rh/gcc-toolset-14/root/usr/lib
RUN curl -L https://github.com/YosysHQ/yosys/releases/download/v0.53/yosys.tar.gz | tar -xzC . && \
    make -j$(nproc) PREFIX=/yosys && \
    make -j$(nproc) PREFIX=/yosys install

# ---
FROM rockylinux:8

RUN dnf install -v -y python38 curl openssl tcl libffi readline

COPY --from=build /root/.cargo/bin/quaigh /usr/bin/quaigh
COPY --from=build /iverilog /iverilog
COPY --from=build /yosys /yosys

ARG FAULT_VERSION
RUN python3 -m pip install --upgrade pip &&\
    python3 -m pip install --upgrade "fault-dft==$FAULT_VERSION" pytest
    
WORKDIR /src
RUN curl -L https://github.com/AUCOHL/Fault/archive/refs/tags/$FAULT_VERSION.tar.gz | \
    tar -xzvC . --strip-components 1

ENV FAULT_IVERILOG=/iverilog/bin/iverilog
ENV FAULT_IVL_BASE=/iverilog/lib/ivl
ENV PATH="/yosys/bin:/iverilog/bin:${PATH}"

# Sanity Checks; OOMs in CI
# RUN PYTEST_FAULT_BIN=fault pytest -v

WORKDIR /
