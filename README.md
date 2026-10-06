# Configurable Multi-Channel FIFO RTL

## Introduction

This project is an in-progress, parameterized SystemVerilog/Verilog FIFO design
intended to support both synchronous and asynchronous clocking. Unlike a basic
single-word FIFO, each address stores multiple independently writable data
channels under a shared read/write pointer. The RTL is separated into top-level,
control/pointer, and memory blocks so that storage behavior, pointer handling,
and integration policy can be studied independently.

The intended feature set includes:

- Configurable data width, channel count, FIFO depth, and pointer width.
- Separate read and write clocks with active-low asynchronous resets.
- Selectable synchronous or asynchronous operation.
- Gray-coded pointer transfer for asynchronous clock-domain crossing.
- Full, empty, almost-full, almost-empty, and per-domain occupancy outputs.
- Per-channel write enables and per-channel memory clearing.
- Support intended for even, non-power-of-two asynchronous depths.
- Optional synchronous low-latency read behavior.
- Selectable old-data or newest-data read semantics.
- Read/write increment blocking controls for test and integration use.
- Underflow detection transferred into the write-clock domain.

## Design philosophy

The design favors configurability and reuse over a minimal FIFO interface. A
shared pointer tracks entries while channel masks control which lanes within an
entry are updated. Pointer generation is isolated in `GFIFO_POINTER`, storage
and output selection are isolated in `GFIFO_MEMORY`, and `GFIFO_CORE` owns flow
control, occupancy calculation, clock-domain handling, and status generation.

For asynchronous operation, the intended CDC strategy follows the established
dual-clock FIFO pattern of Gray-encoding pointers, synchronizing them into the
opposite clock domain, converting them back to binary, and deriving local status
from synchronized pointer values.

## How this differs from a conventional FIFO

This is closer to a configurable, channelized buffering primitive than a small
textbook FIFO. Its distinguishing ideas are the shared pointer with selective
per-channel writes, independent channel clearing, planned non-power-of-two
asynchronous depths, occupancy visibility in both clock domains, configurable
read collision behavior, and a synchronous low-latency option.

Possible applications include multi-lane pipeline buffering, grouped payload
and metadata storage, clock-domain crossing, streaming datapaths, and reusable
ASIC subsystem queues. The channel lanes are not independent FIFOs: they share
the same entry pointers and FIFO occupancy.

## Industry-readiness assessment

The architecture contains several industry-standard concepts, particularly
oversized read/write pointers, Gray-coded asynchronous pointer transfer,
two-domain full/empty calculation, programmable thresholds, and modular
separation of memory and control logic. The broader parameterization is also
representative of reusable internal FIFO IP.

The current source snapshot, however, is **not yet an industry-ready FIFO
implementation**. It does not compile cleanly and has not been accompanied by a
testbench, assertions, CDC constraints, synthesis results, or documented
verification closure. It should currently be treated as a design study or
work-in-progress RTL component, not production-qualified IP.

Known integration issues include:

- Inconsistent identifiers and parameter names, including `gfifo_core` versus
  `GFIFO_CORE`, `MEN_RST_VAL` versus `MEM_RST_VAL`, and `PTR_w` versus `PTR_W`.
- Syntax errors in parameter and port lists and a malformed synchronizer
  instantiation.
- Referenced `sync_2dff` and `sync_2dff_fr` modules are not present here.
- Pointer port-width inconsistencies between the core and pointer module.
- At least one suspicious occupancy expression in `how_full_rd`.
- `NEWEST_DATA=1` is documented in the RTL itself as potentially unsafe in
  asynchronous mode, while both options are enabled by default.
- Configuration legality is described in comments but is not enforced with
  elaboration checks or assertions.

Before calling the design production-quality, it should be made lint- and
compile-clean, supplied with the missing CDC primitives, constrained for CDC
and pointer-bus skew, verified across parameter combinations, checked for RAM
inference and timing, and exercised with assertions plus a self-checking
reference model.

## Source organization

```text
FIFO/
|-- gfifo_top.sv       Integration wrapper and public parameter/interface list
|-- GFIFO_CORE.v       Flow control, CDC intent, flags, and occupancy logic
|-- GFIFO_POINTER.v    Binary/Gray pointer generation and rollover handling
`-- GFIFO_MEMORY.v     Multi-channel storage and registered read output
```

## Current build status

A direct Questa compile currently reports errors:

```bash
vlog -sv gfifo_top.sv GFIFO_CORE.v GFIFO_MEMORY.v GFIFO_POINTER.v
```

Making this command pass, followed by lint, simulation, CDC analysis, and
synthesis checks, is the recommended first milestone before publishing a
verified release.
