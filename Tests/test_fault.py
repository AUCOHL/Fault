import os
import pytest
import subprocess


def run(label, steps):
    for i, step in enumerate(steps):
        print(f"\n=== {label}: Step {i + 1}/6 ===\n")
        subprocess.check_call(["swift", "run", "fault"] + step)


@pytest.mark.parametrize(
    "liberty,models,config,atpg",
    [
        pytest.param(
            "Tech/osu035/osu035_stdcells.lib",
            "Tech/osu035/osu035_stdcells.v",
            "Tech/osu035/config.yml",
            None,
            id="osu035",
        ),
        pytest.param(
            "Tech/osu035/osu035_stdcells.lib",
            "Tech/osu035/osu035_stdcells.v",
            "Tech/osu035/config.yml",
            "Quaigh",
            id="osu035/quaigh",
        ),
        # (
        #     "Tech/sky130_fd_sc_hd/sky130_fd_sc_hd__trimmed.lib",
        #     "Tech/sky130_fd_sc_hd/sky130_fd_sc_hd.v",
        #     "Tech/sky130_fd_sc_hd/config.yml",
        #     id="sky130_fd_sc_hd",
        # ),
    ],
)
def test_spm(request, liberty, models, config, atpg):
    fileName = "Tests/RTL/spm/spm.v"
    topModule = "spm"
    clock = "clk"
    reset = "rst"

    base = os.path.splitext("Netlists/" + fileName)[0]
    fileSynth = base + ".nl.v"
    fileCut = base + ".cut.v"
    fileJson = base + ".tv.json"
    fileChained = base + ".chained.v"
    fileAsmVec = base + ".tv.bin"
    fileAsmOut = base + ".au.bin"

    bypassOptions = ["--clock", clock, "--reset", reset, "--activeLow"]

    for file in [fileSynth, fileCut, fileJson, fileChained, fileAsmVec, fileAsmOut]:
        try:
            os.remove(file)
        except OSError:
            pass

    run(
        request.node.name,
        [
            ["synth", "-l", liberty, "-t", topModule, "-o", fileSynth, fileName],
            ["cut", "-o", fileCut, "--sclConfig", config, fileSynth] + bypassOptions,
            ["bench", fileCut, "--sclConfig", config, fileSynth] + bypassOptions,
            ["-c", models, "-o", fileJson, fileCut] + bypassOptions,
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
