#!/usr/bin/env python3
# Copyright (C) 2025 The American University in Cairo
#
# Adapted from Yosys wheels
#
# Copyright (C) 2024 Efabless Corporation
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
import os
import re
import shlex
import shutil
import platform
from setuptools import setup, Extension
from setuptools.command.build_ext import build_ext

__dir__ = os.path.dirname(os.path.abspath(__file__))

fault_version_rx = re.compile(r"let VERSION\s*=\s*\"([\w\-\+\.]+)\"")

version = fault_version_rx.search(
    open(
        os.path.join(__dir__, "Sources", "Fault", "Entries", "main.swift"),
        encoding="utf8",
    ).read()
)[1]


class fault_exe(Extension):
    def __init__(
        self,
    ) -> None:
        super().__init__(
            "fault.exe",
            [],
        )
        self.args = []

    def custom_build(self, bext: build_ext):
        bext.spawn(
            [
                "swift",
                f"build",
                "-c",
                "release",
                *(["--static-swift-stdlib"] * (platform.system() != "Darwin")),
                "--product",
                "fault",
            ]
            + shlex.split(os.getenv("spmFlags", ""))
            + self.args
        )
        build_path = os.path.dirname(os.path.dirname(bext.get_ext_fullpath(self.name)))
        module_path = os.path.join(build_path, "fault")
        target = os.path.join(module_path, os.path.basename(self.name))
        try:
            os.unlink(target)
        except FileNotFoundError:
            pass
        shutil.copy(os.path.join(".build", "release", "fault"), target)


class custom_build_ext(build_ext):
    def build_extension(self, ext) -> None:
        if not hasattr(ext, "custom_build"):
            return super().build_extension(ext)
        return ext.custom_build(self)


setup(
    name="fault-dft",
    packages=["fault"],
    version=version,
    description="Open source DFT toolchain",
    long_description=open(os.path.join(__dir__, "Readme.md")).read(),
    long_description_content_type="text/markdown",
    install_requires=open("requirements.txt").read().strip().splitlines(),
    classifiers=[
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Intended Audience :: Developers",
        "Operating System :: POSIX :: Linux",
        "Operating System :: MacOS :: MacOS X",
    ],
    python_requires=">=3.8",
    ext_modules=[fault_exe()],
    cmdclass={
        "build_ext": custom_build_ext,
    },
    entry_points={
        "console_scripts": [
            "fault = fault.__main__:exec_fault",
        ]
    },
)
