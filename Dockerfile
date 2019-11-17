FROM swift:5.0.2-xenial

RUN apt-get update
RUN apt-get install -y apt-utils

# Install Basics
RUN apt-get install -y git curl

# Install Python
RUN rm -rf /usr/lib/python2.7/site-packages
RUN apt-get install -y python python-dev python-pip
RUN apt-get install -y python3 python3-dev python3-pip

# Install jinja
RUN python3 -m pip install --upgrade pip
RUN python3 -m pip install jinja2

# Install Yosys
RUN apt-get install -y yosys

# Install IcarusVerilog 10.2+
## Install make and build-essential for IcarusVerilog
    RUN apt-get install -y make build-essential autoconf gperf flex bison
RUN mkdir -p /share/iverilog-setup
WORKDIR /share/iverilog-setup
RUN curl -sL https://github.com/steveicarus/iverilog/archive/v10_2.tar.gz | tar -xzf -
WORKDIR /share/iverilog-setup/iverilog-10_2
RUN autoconf -f
RUN ./configure
RUN make -j$(nproc)
RUN make install exec_prefix=/usr/local

# Install Fault
WORKDIR /share
RUN git clone --depth 1 --recurse-submodules https://github.com/Cloud-V/Fault
WORKDIR /share/Fault
RUN INSTALL_DIR=/usr/bin swift install.swift
WORKDIR /