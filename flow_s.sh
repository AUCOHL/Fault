#!/bin/bash
set -e
set -x
export FAULT_BIN=${FAULT_BIN:-fault}
export DESIGN=${DESIGN:-s27}
$FAULT_BIN synth -l Tech/osu035/osu035_stdcells.lib -t $DESIGN -o Netlists/$DESIGN.nl.v Benchmarks/ISCAS_89/$DESIGN.v
$FAULT_BIN cut --sclConfig Tech/osu035/config.yml Netlists/$DESIGN.nl.v --clock CK --reset reset --bypassing VDD --bypassing GND
rm -f Netlists/$DESIGN.bench
# yosys-abc -F /dev/stdin <<HD
# read Tech/osu035/osu035_stdcells.lib
# read -m Netlists/$DESIGN.cut.v
# write_bench Netlists/$DESIGN.bench
# HD
$FAULT_BIN bench -c Tech/osu035/osu035_stdcells.v Netlists/s27.cut.v
ATPG_FLAGS=
if [ "$ATPG" != "" ]; then
    ATPG_FLAGS="-g $ATPG -b Netlists/$DESIGN.bench "
fi
$FAULT_BIN atpg $ATPG_FLAGS\
    -c Tech/osu035/osu035_stdcells.v\
    --clock CK --reset reset --bypassing VDD --bypassing GND\
    --output-coverage-metadata Netlists/$DESIGN.${ATPG}_coverage.yml\
    Netlists/$DESIGN.cut.v
$FAULT_BIN chain\
    -c Tech/osu035/osu035_stdcells.v\
    --clock CK --reset reset --bypassing VDD --bypassing GND\
    -l Tech/osu035/osu035_stdcells.lib\
    --sclConfig Tech/osu035/config.yml Netlists/$DESIGN.nl.v
$FAULT_BIN asm Netlists/$DESIGN.tv.json Netlists/$DESIGN.chained.v
$FAULT_BIN tap  \
    --clock CK --reset reset --bypassing VDD --bypassing GND\
    -c Tech/osu035/osu035_stdcells.v\
    -l Tech/osu035/osu035_stdcells.lib\
    -t Netlists/$DESIGN.tv.bin\
    -g Netlists/$DESIGN.au.bin\
    Netlists/$DESIGN.chained.v
