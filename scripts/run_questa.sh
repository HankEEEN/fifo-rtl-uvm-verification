#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
if [[ ! -d work ]]; then
  vlib work
fi
vmap work work
vlog -sv -f filelists/channelized_fifo.f
vsim -c channelized_fifo_smoke_tb -do "run -all; quit -f"
