#!/bin/sh
set -x
set -e

TESTTMPDIR=$(mktemp -d)
trap 'rm -rf -- "$TESTTMPDIR"' EXIT

NETLIST=$TESTTMPDIR/nl.v
CUT=$TESTTMPDIR/cut.v
SIM=$TESTTMPDIR/tvs.json
CHAIN=$TESTTMPDIR/chained.v
ASM=$TESTTMPDIR/asm

fault synth -l ./osu035/osu035_stdcells.lib -o $NETLIST -t spm ./spm.v

fault cut -o $CUT $NETLIST

fault -c ./osu035/osu035_stdcells.v -i rst --clock clk -o $SIM $CUT

fault chain -c ./osu035/osu035_stdcells.v -l ./osu035/osu035_stdcells.lib -o $CHAIN --clock clk --reset rst -i rst $NETLIST

fault asm -o $ASM.vec.bin -O $ASM.out.bin $SIM $CHAIN

fault tap -c ./osu035/osu035_stdcells.v -l ./osu035/osu035_stdcells.lib --clock clk --reset rst -t $ASM.vec.bin -g $ASM.out.bin -i rst $CHAIN

echo "Fault self-test complete!"