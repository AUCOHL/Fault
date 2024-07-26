import os
import shlex
import pytest
import subprocess


def run(label, steps):
    for i, step in enumerate(steps):
        print(f"\n=== {label}: Step {i + 1}/{len(steps)} ===\n")
        if step[0] == "nl2bench":
            cmd = step
        else:
            cmd = shlex.split(os.getenv("PYTEST_FAULT_BIN", "swift run Fault")) + step
        print(f"$ {shlex.join(cmd)}")
        subprocess.check_call(cmd)


@pytest.mark.parametrize(
    "liberty,models,config",
    [
        pytest.param(
            "Tech/osu035/osu035_stdcells.lib",
            "Tech/osu035/osu035_stdcells.v",
            "Tech/osu035/config.yml",
            id="osu035",
        ),
        # (
        #     "Tech/sky130_fd_sc_hd/sky130_fd_sc_hd__trimmed.lib",
        #     "Tech/sky130_fd_sc_hd/sky130_fd_sc_hd.v",
        #     "Tech/sky130_fd_sc_hd/config.yml",
        #     id="sky130_fd_sc_hd",
        # ),
    ],
)
@pytest.mark.parametrize("atpg", ["PRNG", "Quaigh"])
@pytest.mark.parametrize(
    "fileName,topModule,clock,reset,other_bypassed,activeLow",
    [
        pytest.param(
            "Tests/RTL/spm/spm.v",
            "spm",
            "clk",
            "rst",
            [],
            True,
            id="spm",
        ),
        pytest.param(
            "Benchmarks/ISCAS_89/s27.v",
            "s27",
            "CK",
            "reset",
            ["VDD=1", "GND=0"],
            False,
            id="s27",
        ),
        # pytest.param(
        #     "Benchmarks/ISCAS_89/s344.v",
        #     "s344",
        #     "CK",
        #     None,
        #     ["VDD=1", "GND=0"],
        #     False,
        #     id="s344",
        # ),
    ],
)
def test_flat(
    request,
    liberty,
    models,
    config,
    fileName,
    topModule,
    clock,
    reset,
    other_bypassed,
    activeLow,
    atpg,
):
    base = os.path.splitext("Netlists/" + fileName)[0]
    fileSynth = base + ".nl.v"
    fileCut = base + ".cut.v"
    fileJson = base + ".tv.json"
    fileBench = base + ".bench"
    fileChained = base + ".chained.v"
    fileAsmVec = base + ".tv.bin"
    fileAsmOut = base + ".au.bin"

    bypassOptions = ["--clock", clock] + (["--activeLow"] if activeLow else [])
    if reset is not None:
        bypassOptions.append("--reset")
        bypassOptions.append(reset)
    for bypassed in other_bypassed:
        bypassOptions.append("--bypassing")
        bypassOptions.append(bypassed)

    for file in [fileSynth, fileCut, fileJson, fileChained, fileAsmVec, fileAsmOut]:
        try:
            os.remove(file)
        except OSError:
            pass

    atpg_options = []
    if atpg != "PRNG":
        atpg_options = ["-g", atpg, "-b", fileBench]

    run(
        request.node.name,
        [
            ["synth", "-l", liberty, "-t", topModule, "-o", fileSynth, fileName],
            ["cut", "-o", fileCut, "--sclConfig", config, fileSynth] + bypassOptions,
            [
                "nl2bench",
                "-o",
                fileBench,
                "-l",
                liberty,
                fileCut,
            ],
            [
                "atpg",
                "-c",
                models,
                "-o",
                fileJson,
                fileCut,
                "--output-coverage-metadata",
                base + f".{atpg}.coverage.yml",
            ]
            + bypassOptions
            + atpg_options,
            [
                "chain",
                "-c",
                models,
                "-l",
                liberty,
                "-o",
                fileChained,
                "--sclConfig",
                config,
                fileSynth,
            ]
            + bypassOptions,
            ["asm", fileJson, fileChained],
            [
                "tap",
                fileChained,
                "-c",
                models,
                "-l",
                liberty,
                "-t",
                fileAsmVec,
                "-g",
                fileAsmOut,
            ]
            + bypassOptions,
        ],
    )


def test_integration():
    liberty = "Tech/osu035/osu035_stdcells.lib"
    models = "Tech/osu035/osu035_stdcells.v"

    fileName = "Tests/RTL/integration/triple_delay.v"
    topModule = "TripleDelay"
    clock = "clk"
    reset = "rst"

    base = os.path.splitext("Netlists/" + fileName)[0]
    fileSynth = base + ".nl.v"
    fileCut = base + ".cut.v"
    fileJson = base + ".tv.json"
    faultPointsYML = base + ".fault_points.yml"
    coverageYml = base + ".coverage_meta.yml"
    fileChained = base + ".chained.v"
    fileAsmVec = base + ".tv.bin"
    fileAsmOut = base + ".au.bin"

    for file in [fileSynth, fileCut, fileJson, fileChained, fileAsmVec, fileAsmOut]:
        try:
            os.remove(file)
        except OSError:
            pass

    bypassOptions = [
        "--clock",
        clock,
        "--reset",
        reset,
        "--bypassing",
        "rstn",
        "--activeLow",
    ]

    run(
        "osu035",
        [
            [
                "synth",
                "-l",
                liberty,
                "-t",
                topModule,
                "-o",
                fileSynth,
                "--blackboxModel",
                "Tests/RTL/integration/buffered_inverter.v",
                fileName,
            ],
            [
                "cut",
                "-o",
                fileCut,
                "--blackbox",
                "BufferedInverter",
                "--blackboxModel",
                "Tests/RTL/integration/buffered_inverter.v",
                fileSynth,
            ]
            + bypassOptions,
            [
                "atpg",
                "-c",
                models,
                "-o",
                fileJson,
                "--output-faultPoints",
                faultPointsYML,
                "--output-covered",
                coverageYml,
                fileCut,
            ]
            + bypassOptions,
            [
                "chain",
                "-c",
                models,
                "-l",
                liberty,
                "-o",
                fileChained,
                fileSynth,
                "--blackbox",
                "BufferedInverter",
                "--blackboxModel",
                "Tests/RTL/integration/buffered_inverter.v",
            ]
            + bypassOptions,
            ["asm", fileJson, fileChained],
            [
                "tap",
                fileChained,
                "-c",
                models,
                "-l",
                liberty,
                "-t",
                fileAsmVec,
                "-g",
                fileAsmOut,
                "--blackboxModel",
                "Tests/RTL/integration/buffered_inverter.v",
            ]
            + bypassOptions,
        ],
    )
