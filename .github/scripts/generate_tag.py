#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Copyright 2022 The American University in Cairo
# Copyright 2020 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import os
import re

from gh import gh

print("Getting tags…")

latest_tag = None
latest_tag_commit = None
tags = [pair[1] for pair in gh.fault.tags]

main_swift_str = open("./Sources/Fault/Entries/main.swift").read()
version_rx = re.compile(r"let\s+VERSION\s*=\s*\"([\w\.\-]+)\"")
versions = version_rx.findall(main_swift_str)
if len(versions) != 1:
    print(
        f"Invalid main.swift file: VERSION regex returned {len(versions)}/1 versions. Must be exactly 1."
    )
    exit(os.EX_DATAERR)
version = versions[0]

tag_exists = version in tags

if tag_exists:
    print("Tag already exists. Leaving NEW_TAG unaltered.")
else:
    new_tag = version

    print("Found new tag %s." % new_tag)
    gh.export_env("NEW_TAG", new_tag)
