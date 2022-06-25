#!/usr/bin/env python3
import os
import sys
import tempfile
import subprocess

script_dir = os.path.abspath(os.path.dirname(__file__))


def fault(*args, subcommand=None, **kwargs):
    cmd = ["fault"]

    if subcommand is not None:
        cmd.append(subcommand)

    for k, v in kwargs.items():
        cmd.append(f"--{k}")
        cmd.append(v)

    cmd += list(args)

    print(f"$ {' '.join(cmd)}")
    sys.stdout.flush()
    sys.stderr.flush()

    subprocess.check_call(cmd)
    sys.stdout.flush()
    sys.stderr.flush()


def main(argv):
    try:
        with tempfile.TemporaryDirectory() as test_tmp_dir:
            netlist = f"{test_tmp_dir}/nl.v"
            cut = f"{test_tmp_dir}/cut.v"
            sim = f"{test_tmp_dir}/tvs.json"
            chain = f"{test_tmp_dir}/chained.v"
            asm = f"{test_tmp_dir}/asm"

            lib = f"{script_dir}/osu035/osu035_stdcells.lib"
            model = f"{script_dir}/osu035/osu035_stdcells.v"

            fault(
                f"{script_dir}/spm.v",
                subcommand="synth",
                liberty=lib,
                top="spm",
                output=netlist,
            )

            fault(netlist, subcommand="cut", output=cut)

            fault(
                cut,
                cellModel=model,
                ignoring="rst",
                clock="clk",
                output=sim,
            )

            fault(
                netlist,
                subcommand="chain",
                cellModel=model,
                liberty=lib,
                output=chain,
                clock="clk",
                reset="rst",
                ignoring="rst",
            )

            fault(
                sim,
                chain,
                subcommand="asm",
                output=f"{asm}.vec.bin",
                goldenOutput=f"{asm}.out.bin",
            )

            fault(
                chain,
                cellModel=model,
                liberty=lib,
                subcommand="tap",
                clock="clk",
                reset="rst",
                testVectors=f"{asm}.vec.bin",
                goldenOutput=f"{asm}.out.bin",
                ignoring="rst",
            )

            print("Fault test successful.")
    except subprocess.CalledProcessError as e:
        print(f"{e}")
        print(f"Command: {' '.join(e.cmd)}")
        exit(-1)


if __name__ == "__main__":
    main(sys.argv)
