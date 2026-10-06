# Configurable Channelized FIFO RTL

## Introduction

This repository contains a parameterized SystemVerilog FIFO that can operate
with one shared clock or as a dual-clock asynchronous FIFO.  Each FIFO entry is
split into independently writable data channels, while all channels share the
same read/write pointers and occupancy.  The design therefore works well for
grouped payload/metadata storage, lane-based pipelines, reusable subsystem
queues, and clock-domain-crossing buffers.

Main features:

- Configurable data width, channel count, depth, pointer width, thresholds, and
  reset value.
- Synchronous and asynchronous operating modes.
- Gray-coded pointer transfer with two-stage destination-domain synchronizers.
- Full, empty, almost-full, almost-empty, and domain-local occupancy outputs.
- Per-channel write enables and per-channel storage/output clearing.
- Power-of-two depths, depth one, and even non-power-of-two asynchronous depths.
- Registered conventional reads or synchronous first-word fall-through through
  `LOW_LATENCY`.
- Read/write increment blocking controls.
- Write-domain overflow pulse and handshake-transferred underflow pulse.
- Elaboration checks and simulation assertions for illegal configurations,
  occupancy bounds, and asynchronous Gray transitions.

## Design philosophy

The design separates the concerns that matter in a reusable FIFO:

- `channelized_fifo_pointer` owns pointer rollover and the CDC-safe skipped count sequence
  used by even, non-power-of-two asynchronous depths.
- `channelized_fifo_memory` owns channel-masked storage, clearing, registered reads, and
  synchronous read-during-write behavior.
- `channelized_fifo_gray_sync` and `channelized_fifo_event_sync` provide the
  pointer and event CDC mechanisms.
- `channelized_fifo_core` combines local and synchronized pointer views to generate flow
  control, occupancy, error indications, and memory controls.
- `channelized_fifo` is the public integration wrapper.

This is different from a set of independent FIFOs.  A `write` bit controls one
lane within the current entry, but `winc` advances the one shared write pointer.
Likewise, one `rinc` consumes the complete multi-channel entry.

### Important interface contracts

- For a normal enqueue, assert the desired `write[CHANS-1:0]` mask and `winc`
  together.  They remain deliberately independent so an integration can update
  channel storage without advancing the pointer, matching the original design.
- A channel with `write[n] == 0` retains the previous contents of that physical
  memory lane. After pointer wraparound, the retained value may belong to an
  older transaction rather than `MEM_RST_VAL`. This behavior allows an entry
  to be assembled across multiple write clocks before `winc` commits it.
- `block_winc` and `block_rinc` suppress pointer increments.  `block_winc` does
  not suppress an independently requested channel write.
- In synchronous mode, connect `clk_wr` and `clk_rd` to the same clock.  Use
  asynchronous mode for unrelated or differently timed clocks.
- In asynchronous mode, flags and occupancy are intentionally conservative:
  synchronized remote pointers arrive a few destination-clock cycles late.
- Assert `rst_wr_an` and `rst_rd_an` together. Their asynchronous assertion and
  deassertion must be safe for their respective local clock domains. Resetting
  only one side is outside the supported data-preservation contract.
- Assert `clear_wr` and `clear_rd` together when flushing the FIFO.  In
  asynchronous mode their assertion windows must overlap long enough that
  each domain observes the other pointer at its cleared value; the supplied
  UVM test holds both for four local active edges.  This resets both local
  pointers and their synchronized remote views.  Independent or isolated
  one-cycle pointer clears are exposed for compatibility, but are not a safe
  asynchronous flush because the domains can temporarily disagree about
  occupancy.
- `clear_chan_wr[n]` clears channel `n` in every storage entry;
  `clear_chan_rd[n]` clears channel `n` in the registered read output.
- An asynchronous underflow is delivered as a write-clock pulse through a
  request/acknowledge CDC.  Repeated underflows while one event is still pending
  are coalesced into that pending indication.
- `wr_ptr_bin` and `rd_ptr_bin` are diagnostic outputs in their respective
  local clock domains. They are not safe to consume directly across a clock
  boundary.

## Configuration

The most important parameters are:

| Parameter | Meaning |
|---|---|
| `DATA_W` | Bits in each channel |
| `CHANS` | Channels stored at each FIFO address |
| `LENGTH` | Number of FIFO entries |
| `PTR_W` | Address width; must cover `LENGTH` |
| `ASYNCHRONOUS` | `1` for unrelated clocks, `0` for a shared clock |
| `AE_LIMIT` | `almost_empty` occupancy threshold |
| `AF_LIMIT` | Free-entry threshold used by `almost_full` |
| `LOW_LATENCY` | Synchronous first-word fall-through/prefetch mode |
| `MEM_RST_VAL` | Storage and output reset/clear value |
| `WR_PTR_DEF`, `RD_PTR_DEF` | Initial logical pointer values |

Legal configuration rules are checked during simulation:

- `1 <= LENGTH <= 2**PTR_W` and `PTR_W >= 1`.
- A non-power-of-two asynchronous `LENGTH` greater than one must be even.
- `AE_LIMIT` and `AF_LIMIT` cannot exceed `LENGTH`.
- `LOW_LATENCY` is a synchronous-only feature.
- Read/write default pointers must match so reset represents an empty FIFO.

## Source organization

```text
FIFO/
|-- channelized_fifo.sv                 Public wrapper
|-- channelized_fifo_core.sv            Flow control and integration
|-- channelized_fifo_pointer.sv         Logical/binary/Gray pointers
|-- channelized_fifo_memory.sv          Multi-channel storage
|-- channelized_fifo_gray_sync.sv       Gray-pointer synchronizer
|-- channelized_fifo_event_sync.sv      Event-handshake synchronizer
|-- filelists/channelized_fifo_rtl.f    Synthesizable RTL source list
|-- filelists/channelized_fifo.f        RTL and smoke-test source list
|-- filelists/channelized_fifo_uvm.f    RTL and UVM source list
|-- docs/UVM_TEST_PLAN.md               Deterministic verification plan
|-- scripts/run_questa.sh               Git Bash smoke-test command
|-- scripts/run_uvm_questa.sh           Git Bash UVM matrix command
|-- tb/channelized_fifo_smoke_tb.sv     Self-checking smoke regression
`-- tb/uvm/                             UVM agents, model, tests, and assertions
```

All RTL and testbench sources use the `.sv` extension because they contain
SystemVerilog constructs such as `logic`, `always_comb`, `always_ff`, typed
parameters, variable part-selects, and assertions.  The build still passes
`-sv` explicitly so the selected language is unambiguous across tools.

## Running the smoke test

From Git Bash in the repository root:

```bash
bash scripts/run_questa.sh
```

The equivalent manual Questa commands are:

```bash
if [[ ! -d work ]]; then vlib work; fi
vmap work work
vlog -sv -f filelists/channelized_fifo.f
vsim -c channelized_fifo_smoke_tb -do "run -all; quit -f"
```

The smoke test checks:

- reset state, occupancy, and almost/full/empty thresholds;
- per-channel writes and channel clearing;
- partial-entry assembly and retained unselected-channel data after wraparound;
- increment blocking, overflow, and underflow;
- ordered data through a conventional synchronous FIFO;
- low-latency first-word fall-through, prefetch, and simultaneous replacement;
- a complete fill/drain of a 12-entry asynchronous FIFO, including both
  non-power-of-two Gray-code skip transitions;
- nonzero pointer reset defaults in both synchronous and asynchronous modes;
- coordinated asynchronous pointer/synchronizer clearing;
- pointer synchronization and underflow transfer between unrelated clocks.

The expected completion message is:

```text
Channelized FIFO smoke test PASSED
```

## Running the UVM regression

The UVM regression is the thorough verification suite.  It uses deterministic
directed algorithms rather than constrained randomization, so it is compatible
with Questa Starter.  It includes independent write/read UVM agents, a
cycle-accurate physical-memory and FIFO reference model, fatal interface
assertions, boundary/error tests, repeated pointer wraparound, low-latency
tests, and CDC tests with both write-fast/read-slow and write-slow/read-fast
clock ratios.

From Git Bash in the repository root:

```bash
bash scripts/run_uvm_questa.sh
```

The script uses Questa's precompiled `mtiUvm` UVM 1.1d library and defaults to
this Quartus Lite installation path:

```text
D:/quartus_24.1_lite/questa_fse/verilog_src/uvm-1.1d/src
```

If Questa is installed elsewhere, override the source location for the macro
include before running the script:

```bash
UVM_SRC="D:/path/to/questa/verilog_src/uvm-1.1d/src" \
  bash scripts/run_uvm_questa.sh
```

The script recompiles and runs six configurations: normal synchronous,
low-latency synchronous, asynchronous depth 12, asynchronous depth 8 with the
opposite clock ratio, depth one, and a three-channel parameter variation with
nonzero memory/pointer reset values.  Per-case logs are written under `logs/`.
It stops on the first compile, assertion, UVM, or missing-pass-marker failure.
Successful completion ends with:

```text
FIFO UVM regression PASSED
```

The complete scenario matrix and pass criteria are in
[`docs/UVM_TEST_PLAN.md`](docs/UVM_TEST_PLAN.md).

Optional lint command (run from an environment where Verilator is configured):

```bash
verilator --lint-only -Wall -Wno-fatal \
  -f filelists/channelized_fifo_rtl.f --top-module channelized_fifo
```

## Industry-readiness assessment

The control architecture now uses standard industry FIFO techniques: an extra
wrap bit, Gray-coded asynchronous pointers, two-stage synchronizers, local
full/empty decisions, conservative cross-domain visibility, parameter checks,
and self-checking simulation.  The channelized entry mask and even
non-power-of-two Gray skip sequence are useful extensions beyond a textbook
FIFO.

The RTL is compile-clean and the included regression passes, but that alone is
not production sign-off.  A target project still needs:

- CDC constraints that identify synchronizer registers and limit source Gray
  bus skew to one source-clock period;
- reset-domain analysis proving that assertion is coordinated and that each
  reset is released safely in its local clock domain;
- additional coverage closure and formal full/empty proofs across the complete
  product-specific parameter matrix;
- synthesis, RAM-inference, timing, and power checks for the target FPGA/ASIC;
- a decision about whether clearing every memory word is acceptable, because
  whole-array reset and per-channel clearing can prevent block-RAM inference;
- coverage closure and project-specific error/flush semantics.

Accordingly, this is a solid educational and reusable RTL baseline, but it
should not be described as production-qualified FIFO IP until those target
specific checks are complete.
