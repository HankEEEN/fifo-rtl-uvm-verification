#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

UVM_SRC="${UVM_SRC:-D:/quartus_24.1_lite/questa_fse/verilog_src/uvm-1.1d/src}"
mkdir -p logs

run_case() {
  local case_name="$1"
  local test_name="$2"
  shift 2
  local library="uvm_work_${case_name}"

  if [[ ! -d "$library" ]]; then
    vlib "$library"
  fi
  vmap -modelsimini modelsim.ini "$library" "$library"
  vlog -modelsimini modelsim.ini -sv -L mtiUvm \
    "+incdir+${UVM_SRC}" -work "$library" "$@" \
    -f filelists/channelized_fifo_uvm.f
  local log_file="logs/uvm_${case_name}.log"
  vsim -modelsimini modelsim.ini -c -lib "$library" -L mtiUvm \
    channelized_fifo_uvm_tb "+UVM_TESTNAME=${test_name}" \
    -l "$log_file" -do "run -all; quit -f"
  if grep -Eq 'UVM_(ERROR|FATAL) :[[:space:]]+[1-9]|\*\* (Error|Fatal):' "$log_file"; then
    echo "FIFO UVM case ${case_name} FAILED; see ${log_file}" >&2
    return 1
  fi
  if ! grep -q 'FIFO UVM test PASSED' "$log_file"; then
    echo "FIFO UVM case ${case_name} ended without its pass marker" >&2
    return 1
  fi
}

run_case sync channelized_fifo_sync_test \
  +define+FIFO_LENGTH=4 +define+FIFO_PTR_W=2 +define+FIFO_CHANS=2

run_case low_latency channelized_fifo_low_latency_test \
  +define+FIFO_LENGTH=4 +define+FIFO_PTR_W=2 +define+FIFO_CHANS=2 \
  +define+FIFO_LOW_LATENCY=1

run_case async_np2 channelized_fifo_async_test \
  +define+FIFO_LENGTH=12 +define+FIFO_PTR_W=4 +define+FIFO_CHANS=2 \
  +define+FIFO_ASYNC=1 +define+FIFO_WR_HALF_NS=5 \
  +define+FIFO_RD_HALF_NS=7 +define+FIFO_RD_PHASE_NS=1

run_case async_pow2 channelized_fifo_async_test \
  +define+FIFO_LENGTH=8 +define+FIFO_PTR_W=3 +define+FIFO_CHANS=2 \
  +define+FIFO_ASYNC=1 +define+FIFO_WR_HALF_NS=11 \
  +define+FIFO_RD_HALF_NS=3 +define+FIFO_RD_PHASE_NS=1

run_case depth_one channelized_fifo_sync_test \
  +define+FIFO_LENGTH=1 +define+FIFO_PTR_W=1 +define+FIFO_CHANS=1

run_case parameterized channelized_fifo_sync_test \
  +define+FIFO_LENGTH=6 +define+FIFO_PTR_W=3 +define+FIFO_CHANS=3 \
  +define+FIFO_AE_LIMIT=2 +define+FIFO_AF_LIMIT=2 \
  +define+FIFO_MEM_RST_VAL=165 +define+FIFO_PTR_DEF=3

echo "FIFO UVM regression PASSED"
