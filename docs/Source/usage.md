# Usage Example

In this tutorial, we will show a typical flow of an RTL design starting from
synthesis all the way to fault simulations and chain insertion.

We will use the `s27` design which could be found in
[Benchmarks/ISCAS_89/s27.v](https://github.com/AUCOHL/Fault/blob/master/Benchmarks/ISCAS_89/s27.v).

## Assumptions

We assume you've cloned the current repository and you are using it as your
current working directory.

If you're using Nix without installing to `PATH`, replace `fault` with
`nix run .#fault --`.

## Synthesis

The first step is to generate a synthesized netlist for the `s27` module and we
will use the `synth` command with the following options:

```bash
fault synth -l <liberty-file> -t <top-module-name> [-o <output-netlist-path>]. <RTL-design-path> 
```

- `-l` : specifies the path to the liberty file of the standard cell library to
  which the RTL design is to be mapped to.

- `-t`: specifies the top module of the design.

- `-o`: specifies the path of the output netlist. In this example, we will use
  the default path which is `Netlists/ + <top-module-name> + .nl.v`

To generate the synthesized netlist, run :

```bash
fault synth\
  -t s27 \
  -l Tech/osu035/osu035_stdcells.lib \
  -o Netlists/s27.nl.v \
  Benchmarks/ISCAS_89/s27.v
```

This will run a yosys-based synthesis script and it will generate a flattened
netlist at `Netlists/s27.nl.v`.

- For combinational circuits, add dummy clock and reset ports to the design. The
  clock port doesn't have to be connected to anything, necessarily, but will be
  used by Fault DFT later for the generated scan-chain.

## Netlist Cutting

Since the `s27` module contains sequential elements, performing netlist cutting
is necessary for the fault simulations. (This step is not required for purely
combinational designs.)

```bash
fault cut [-o <output-cut-netlist-path>] [--sclConfig <scl configuration file>] <flattened-netlist-path>
<bypass options> 
```

```{note} Bypass Options
You will notice a new option called "bypass options."

Bypass options are shared across multiple steps. They list signals that are
to be bypassed by the scan-chain insertion process. This includes but is not 
limited to:
* Clocks
* Resets
* VDD
* GND

The flags are as follows:
* `--clock`: The name of the clock signal
* `--reset`: The name of the active-high reset signal
* `--activeLow`: Sets the reset to active-low instgead
* `--bypassing NAME[=0|1]`: Additional signals to bypass. Bypassed signals are
  held low during simulations, but by adding `=1`, they will be held high
  instead.

```

To generate the cut netlist, run:

```bash
fault cut Netlists/s27.nl.v --clock CK --reset reset --bypassing VDD=1 --bypassing GND=0
```

This will remove all the netlist flip flops converting it into a pure
combinational netlist. The removed flip-flops will be exposed as input and
output ports. The generated comb-only (only combinational logic) netlist default
path is: `Netlists/s27.cut.v`

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
fault [-v <initial TV count>] [-r <increment>] [-m <minCoverage>] [--ceiling <TV count ceiling>] [-c <cell models>] <netlist> <bypass options> 
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

In this example, we will use a minimum coverage of `95%`, an increment of `50`,
an initial test vector set size of `100` , and a ceiling of `1000` test vectors.

We will also use the default value for `-g` option where swift's system
generator will be used for pseudo-random number generation.

To run the simulations, invoke the following:

```bash
fault -c Tech/osu035/osu035_stdcells.v -v 100 -r 50 -m 95 --ceiling 1000 Netlists/s27.cut.v --clock CK --reset reset --bypassing VDD=1 --bypassing GND=0
```

This will generate the coverage at the default path:
`Netlists/s27.tv.json`.

### B) Using Quaigh or Atalanta

In this part, we will use an external test vector generation. But, before
running the simulations we have to convert the comb-only netlist (.cut netlist)
to the .bench format accepted by Quaigh or Atalanta. We use a tool called
`nl2bench` to do that.

```{note}
Quaigh is bundled with Fault, but Atalanta is not as it is proprietary software.
```

```bash
nl2bench <cut netlist> -o <path to output bench file> -l <liberty file 0> [-l <liberty file 1> [-l <liberty file 2> …]]
```

- `-l`: Path to the lib files. At least one must be specified, but
  you may specify multiple.
- `-o`: Path of the output bench netlist. Default is
  `<comb-only-netlist-path> + .bench

To generate a .bench netlist, invoke the following:

```bash
nl2bench -o Netlists/s27.bench -l Tech/osu035/osu035_stdcells.lib Netlists/s27.cut.v
```

After the bench netlist is created, we can generate test vectors 
and run fault simulations by setting the following options:

- `-g`: Type of the test vector generator.
- `-c`: Cell models file path.
- `-b`: Path to the bench netlist.

```bash
fault atpg -g [Atalanta|Quaigh] -c Tech/osu035/osu035_stdcells.v -b Netlists/s27.bench Netlists/s27.cut.v --clock CK --reset reset --bypassing VDD=1 --bypassing GND=0
```

This will run the simulations with the default options for the initial TV count,
increment, and ceiling. TV coverage will be generated at the default path
`Netlists/s27.tv.json`

## Scan Chain Insertion

`Chain` performs scan chain insertion through the netlist's internal flip-flops.
It has the following options:

```bash
fault chain -l <liberty-file> -c <cell-models-file> -o <path-to-chained-netlist> <flattened-netlist-path> <bypass options>
```

- `-l`: specifies the path to the liberty file of the standard cell library.
- `-c`: cell models file to verify the scan chain integrity.
- `-o`: path of the chained netlist.

The chained netlist could be generated by running:

```bash
fault chain\
  --clock CK --reset reset --bypassing VDD=1 --bypassing GND=0\
  -l Tech/osu035/osu035_stdcells.lib\
  -c Tech/osu035/osu035_stdcells.v\
  Netlists/s27.nl.v
```

This will generate the chained netlist at the default path:
`Netlists/s27.nl.v.chained.v`

## JTAG Interface Insertion

In this part, we will add the JTAG port to the chained netlist. To run tap, we
set the following options:

- `-o`: Path to the output file. (Default: input + .jtag.v)
- `-c`: Cell models file to verify JTAG port using given cell model.
- `-l`: Path to the liberty file for resynthesis.
- Bypass options

To run tap option, invoke the following

```bash
fault tap\
  --clock CK --reset reset --bypassing VDD --bypassing GND\
  -l Tech/osu035/osu035_stdcells.lib\
  -c Tech/osu035/osu035_stdcells.v\
  Netlists/s27.chained.v
```
