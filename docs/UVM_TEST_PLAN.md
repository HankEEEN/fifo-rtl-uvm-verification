# Channelized FIFO UVM Test Plan

## 1. Purpose and scope

This plan verifies `channelized_fifo` at its public interface.  It covers the
shared FIFO control path, independent per-channel memory writes and clears,
registered and low-latency reads, boundary/error behavior, parameter edge
cases, and asynchronous clock-domain crossings (CDC).

The regression is deliberately deterministic.  It uses directed algorithms,
data patterns, clock-ratio sweeps, and repeated wraparound instead of
SystemVerilog constrained randomization, so it runs on Questa Starter and is
exactly reproducible.

## 2. Testbench architecture

- A write UVM agent drives `winc`, the channel write mask, write data, write
  blocking, and write-side clears.
- A read UVM agent independently drives `rinc`, read blocking, and read-side
  clears.
- A passive cycle-accurate scoreboard mirrors every physical memory lane,
  logical write/read pointer, queued entry, flag, and error event.  This is
  important because a disabled lane retains the old value in its physical
  address and because lane writes are legal without advancing the FIFO.
- Interface assertions check flag/occupancy consistency, known-valued control
  outputs, legal pointer holds, and occupancy bounds.
- The RTL's own assertions check legal Gray transitions and local FIFO safety.

No class member is declared `rand`, no constraint block is present, and the
testbench never calls `randomize()`.

## 3. Required configurations

| Configuration | Important parameters | Purpose |
|---|---|---|
| `sync` | depth 4, 2 channels | Main synchronous behavior and wraparound |
| `low_latency` | depth 4, 2 channels, `LOW_LATENCY=1` | First-word fall-through, prefetch, replacement |
| `async_np2` | depth 12, pointer width 4 | Unrelated clocks and non-power-of-two Gray skip |
| `async_pow2` | depth 8, pointer width 3 | Unrelated clocks with opposite fast/slow ratio |
| `depth_one` | depth 1, pointer width 1, 1 channel | Supported minimum-depth boundary |
| `parameterized` | depth 6, 3 channels, nonzero pointer default, nonzero memory reset value | Widths, thresholds, reset defaults, and even non-power-of-two synchronous depth |

The regression script recompiles the parameterized testbench for every row.

## 4. Functional scenarios and checks

### Reset and clear

- Assert both asynchronous resets and verify empty state, reset pointers,
  occupancy zero, reset data, and inactive error pulses.
- Apply overlapping, multi-cycle coordinated pointer clears while data is
  present and verify both logical domains return to the configured pointer
  default.  The overlap is intentionally long enough for unrelated clocks;
  an isolated one-cycle pulse in each domain is not a safe CDC flush.
- Clear one storage channel and verify all addresses in that lane become
  `MEM_RST_VAL` without modifying other lanes.
- Verify a storage-channel clear wins over a same-edge write to that lane.
- Verify a read-output channel clear wins over a same-edge read.

### Data and channel semantics

- Enqueue/dequeue full-channel entries and compare every bit.
- Assemble one entry with channel writes on separate cycles before `winc`.
- Exercise sparse channel masks and verify disabled lanes retain the previous
  contents of the reused physical slot.
- Wrap both pointers repeatedly and preserve FIFO ordering.
- Exercise `write` without `winc` and `winc` without `write` as legal, distinct
  operations under the documented programming contract.

### Capacity, flow control, and errors

- Visit every occupancy from empty through full and back to empty.
- Check exact `how_full_*`, `empty`, `full`, `almost_empty`, and `almost_full`
  behavior in synchronous mode.
- Reject an enqueue at full and check the one-cycle overflow indication.
- Reject a dequeue at empty and check synchronous or transferred asynchronous
  underflow indication.
- Verify `block_winc` and `block_rinc` hold their respective pointers and do
  not generate overflow/underflow.

### Low-latency behavior

- Check first-word fall-through when writing an empty FIFO.
- Check automatic prefetch of the next head after a dequeue.
- Check simultaneous dequeue/enqueue replacement at occupancy one.
- Check simultaneous dequeue/enqueue while full (the read releases space).
- Check channel-clear priority over write-through.

### CDC behavior

- Use independent clocks with different periods and a phase offset so their
  active edges do not coincide in simulation.
- Run both write-faster-than-read and read-faster-than-write configurations.
- Run a deterministic concurrent producer/consumer stream while both pointers
  cross domains continuously.
- Traverse both non-power-of-two Gray skip transitions repeatedly.
- Check that synchronized occupancy remains bounded, data remains ordered,
  full/empty decisions are conservative, and an underflow event reaches the
  write domain.
- Apply coordinated clears and resets while clocks are unrelated.

Simulation cannot create analog metastability or replace a structural CDC
tool.  Production sign-off still requires recognition of the two-flop
synchronizers, asynchronous-clock constraints, a Gray-bus max-skew constraint,
and reset-domain analysis.

## 5. Assertions

The testbench assertions require:

- `how_full_wr` and `how_full_rd` never exceed `LENGTH`;
- `full` is equivalent to write-domain occupancy equal to `LENGTH`;
- `empty` is equivalent to read-domain occupancy equal to zero;
- public flags, occupancies, and pointers contain no X/Z after reset;
- rejected or blocked operations do not advance their pointer;
- pointer clears restore the configured pointer values.

Assertion failures are fatal so a batch regression cannot silently pass.

## 6. Pass criteria

Every configuration must finish with zero UVM errors/fatals, zero assertion
failures, zero scoreboard mismatches, an empty expected-data queue, and the
expected boundary/error/CDC events observed.  The batch script stops on the
first compile or simulation failure and prints `FIFO UVM regression PASSED`
only after all configurations pass.

