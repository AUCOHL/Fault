# Fault Documentation

Fault is a complete open source design for testing (DFT) solution. It includes
automatic test pattern generation (ATPG), scan stitching, static test vector
compaction, and JTAG insertion. Fault generates test vectors pseudo-randomly and
performs fault simulations using the stuck-at-fault model.

<div align="center">
<img src="https://user-images.githubusercontent.com/25064257/80364707-a6950280-8886-11ea-9fd6-d8dbbc689081.png">
<p> Fault Design Flow. </p>
</div>

Fault is composed of seven main options:

## 1. Synth

Synth is a [Yosys-based](https://github.com/YosysHQ/Yosys) synthesis script that
synthesizes and maps Verilog RTL into a flatten netlist using a standard cell
library. Since Fault is compatible with any flatten netlist, this option could
be skipped if the user wants to run their own synthesis script.

## 2. Cut

Cut removes the flip flops from the flatten netlist and converts it into a pure
combinational design.

## 3. ATPG

ATPG is the main event. It runs Fault simulations for a generated test vector
set using the stuck-at fault model. The test vector set could be supplied to the
simulator externally or it could be internally generated using a pseudo-random
number generator or by using [Atalanta](https://github.com/hsluoyz/Atalanta).

Fault supports two random number generators Swift system default generator and a
linear feedback shift register (LFSR).

ATPG also optimizes the test vector set by eliminating redundant vectors.

### 4. Chain

Chain performs scan-chain stitching. Using
[Pyverilog](https://github.com/PyHDI/Pyverilog), a boundary scan chain is
constructed through a netlist's input and output ports. An internal register
chain is also constructed through the netlist's D-flip-flops.

### 5. Tap

Tap adds the
[JTAG interface](https://opencores.org/websvn/listing?repname=adv_debug_sys&path=%2Fadv_debug_sys%2Ftrunk%2FHardware%2Fjtag%2Ftap%2Fdoc%2F#path_adv_debug_sys_trunk_Hardware_jtag_tap_doc_)
to a chained netlist. This is accomplished by adding its five namesake test
access ports: serial test data in (TDI), test mode select (TMS) which navigates
an internal finite state machine, serial test data out (TDO), test clock (TCK),
and an active low test reset signal (TRST).The interface has been extended to
support a custom instruction (ScanIn) to select the internal register scan
chain.

## Tutorial

For a walk-through tutorial on how to use Fault, check the sidebar.

```{toctree}
:glob:
:hidden:

installation
usage
benchmarks
```

---

Documentation text and images are licensed under a
<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative
Commons Attribution-ShareAlike 4.0 International License</a>. You are free to
adapt and modify the documentation's content so long as your changes are
released under the same license.

By contributing to this documentation, you represent that you:
1. Have the right to license your contribution to the general public.
2. Agree that your contributions are irrevocably licensed under the same
   licenses linked above.

The Fault software itself is available under the Apache 2.0 license,
available in the repository.
