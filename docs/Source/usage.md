# Usage Example

In this tutorial, we will show a typical flow of an RTL design starting from
synthesis all the way to fault simulations and chain insertion.

We will use the `s27` design which could be found in
[Benchmarks/ISCAS_89/s27.v](https://github.com/AUCOHL/Fault/blob/master/Benchmarks/ISCAS_89/s27.v).

## Assumptions

We also assume you've cloned the current repository and you are using it as your
current working directory.

## Synthesis

The first step is to generate a synthesized netlist for the `s27` module and we
will use the `synth` command with the following options:

```bash
 fault synth -l <liberty-file>  -t <top-module-name> -o <output-netlist-path> <RTL-design-path> 
```

- `-l` : specifies the path to the liberty file of the standard cell library to
  which the RTL design is to be mapped to.

- `-t`: specifies the top module of the design.

- `-o`: specifies the path of the output netlist. In this example, we will use
  the default path which is `Netlists/ + <top-module-name> + .nl.v`

To generate the synthesized netlist, run :

```bash
 fault synth -t s27 -l Tech/osu035/osu035_stdcells.lib Benchmarks/ISCAS_89/s27.v
```

This will run a yosys-based synthesis script and it will generate a flattened
netlist in the default path at `Netlists/s27.nl.v`.

- For combinational circuits, add dummy clock and reset ports to the design. The
  clock port doesn't have to be connected to anything, necessarily, but will be
  used by Fault DFT later for the generated scan-chain.

## Netlist Cutting

Since the `s27` module contains sequential elements, performing netlist cutting
is necessary for the fault simulations. (This step is not required for purely
combinational designs.)

```bash
 fault cut -o <output-cut-netlist-path> <flattened-netlist-path> 
```

To generate the cut netlist, run:

```bash
 fault cut Netlists/s27.nl.v
```

This will remove all the netlist flip flops converting it into a pure
combinational netlist. The removed flip-flops will be exposed as input and
output ports. The generated comb-only (only combinational logic) netlist default
path is: `Netlists/s27.nl.v.cut.v `

The comb-only netlist is then used for performing fault simulations in the next
step.

## Fault Simulations

Test vectors are generated internally by a random number generator (RNG) or by
using [atalanta](https://github.com/hsluoyz/Atalanta).

### A) Using Internal PRNGs

The test vectors could be simulated incrementally such that the size of the set
is increased if sufficient coverage isn't met. This is done by the following
options:

```bash
fault -v <initial TV count> -r <increment> -m <minCoverage> --ceiling <TV count ceiling> -c <cell models> --clock <clock port> --reset <reset port> [--ignoring <ignored port 1> [--ignoring <ignored port 2> ] ] [ --activeLow] <netlist> 
```

- `-v`: Number of the initially generated test vectors.

- `-m`: Minimum coverage percentage that should be met by the generated test
  vectors.

- `-r`: Increment in the test vector count if minimum coverage isn't met.

- `--ceiling`: Ceiling for the number of generated test vectors. If this number
  is reached, simulations are stopped regardless of the coverage.

- `-g`: Type of the test vector generator. Three types are supported: (1) swift:
  uses Swift system RNG (2) LFSR: uses a linear feedback shift register as a RNG
  (3) atalanta: uses atalanta atpg for generating TVs. Default value is swift.

- `-c`: The cell models to use for simulations.

- `--clock`: The name of the clock port.

- `--ignoring`: The name of any other ports to ignore during ATPG, which will
  be held high.

- `--activeLow`: If set, all ports specified by `--ignoring` will be held low
  instead.

In this example, we will use a minimum coverage of `95%`, an increment of `50`,
an initial test vector set size of `100` , and a ceiling of `1000` test vectors.

We will also use the default value for `-g` option where swift's system
generator will be used for pseudo-random number generation.

To run the simulations, invoke the following:

```bash
fault -c Tech/osu035/osu035_stdcells.v -v 100 -r 50 -m 95 --ceiling 1000 --clock CK --ignoring reset Netlists/s27.nl.v.cut.v
```

This will generate the coverage at the default path:
`Netlists/s27.nl.v.cut.v.tv.json`.

### B) Using Atalanta

In this part, we will set the test vector generator to Atalanta. But, before
running the simulations we have to convert the comb-only netlist (.cut netlist)
to bench format because atalanta is compatible only with bench format.

The bench conversion is supported by `bench` option:

```bash
 fault bench -c <cell-models-file> -o <bench-netlist-output-path> <comb-only-netlist-path>
```

- `-c`: Path of the cell models library. Fault converts the cell library to json
  representation for easier cell extraction. So, if .json file is available from
  previous runs, the file could be passed directly.
- `-o`: Path of the output bench netlist. Default is
  `<comb-only-netlist-path> + .bench`

To generate bench netlist, invoke the following:

```
 fault bench -c Tech/osu035/osu035_stdcells.v  Netlists/s27.nl.v.cut.v
```

This will generate the json representation for the osu035 cell library at:
`Tech/osu035/osu035_stdcells.v.json` which could be used for subsequent runs.

The bench netlist will be generated at ` Netlists/s27.nl.v.cut.v.bench`

After the bench netlist is created, we can generate test vectors using atalanta
and run fault simulations by setting the following options:

- `-g`: Type of the test vector generator. Set to `Atalanta`
- `-c`: Cell models file path.
- `-b`: Path to the bench netlist.

```bash
    fault -g Atalanta -c Tech/osu035/osu035_stdcells.v -b Netlists/s27.nl.v.cut.v.bench Netlists/s27.nl.v.cut.v
```

This will run the simulations with the default options for the initial TV count,
increment, and ceiling. TV coverage will be generated at the default path
`Netlists/s27.nl.v.cut.v.tv.json`

## Compaction

`Compact` option is used to reduce the size of the test vector generated in the
previous step while maintaining the same coverage.

```bash
 fault compact -o <output-compacted-json> <coverage-json>
```

To run compact, invoke:

```bash
 fault compact Netlists/s27.nl.v.cut.v.tv.json
```

This will generate the compacted test vector set which is output in the default
path at: `fault compact Netlists/s27.nl.v.cut.v.tv.json.compacted.json`

## Scan Chain Insertion

`Chain` performs scan chain insertion through the netlist's internal flip-flops.
It has the following options:

```bash
 fault chain -i <inputs-to-ignore> --clock <clk-signal> --reset <rst-signal> -l <liberty-file> -c <cell-models-file> -o <path-to-chained-netlist> <flattened-netlist-path>
```

- `-i`: Specifies the inputs to ignore (if any)
- `--clock`: Clock signal name which is automatically added to the ignored
  inputs.
- `--reset`: **Asynchronous** Reset signal name which is also automaticallyadded
  to the ignored inputs.
  - `--activeLow`: If your reset is active low, also include this flag.
- `-l`: specifies the path to the liberty file of the standard cell library.
- `-c`: cell models file to verify the scan chain integrity.
- `-o`: path of the chained netlist.

The chained netlist could be generated by running:

```bash
 fault chain -l Tech/osu035/osu035_stdcells.lib -c Tech/osu035/osu035_stdcells.v --clock CK --reset reset Netlists/s27.nl.v
```

This will generate the chained netlist at the default path:
`Netlists/s27.nl.v.chained.v`

## JTAG Interface Insertion

In this part, we will add the JTAG port to the chained netlist. To run tap, we
set the following options:

- `-o`: Path to the output file. (Default: input + .jtag.v)
- `--clock`: Clock signal of core logic to use in simulation
- `--reset`: Reset signal of core logic to use in simulation.
- `--ignoring`: Other signals to ignore
- `--activeLow`: Ignored signals (including reset) signal of core logic are held
  low instead of high.
- `-c`: Cell models file to verify JTAG port using given cell model.
- `-l`: Path to the liberty file for resynthesis.

To run tap option, invoke the following

```bash
 fault tap -l Tech/osu035/osu035_stdcells.lib -c Tech/osu035/osu035_stdcells.v -l Tech/osu035/osu035_stdcells.lib -c Tech/osu035/osu035_stdcells.v --clock CK --reset reset Netlists/s27.nl.v.chained.v
```
