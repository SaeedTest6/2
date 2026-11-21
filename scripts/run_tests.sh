#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p sim

run_test() {
    local top="$1"
    shift
    echo "== Building ${top} =="
    iverilog -g2012 -Wall -s "${top}" -o "sim/${top}" "$@"
    echo "== Running ${top} =="
    vvp "sim/${top}"
}

run_test tb_nova_x1_alu \
    rtl/common/nova_pkg.sv rtl/execution/nova_x1_alu.sv tb/tb_nova_x1_alu.sv

run_test tb_nova_x1_regfile \
    rtl/registers/nova_x1_regfile.sv tb/tb_nova_x1_regfile.sv

run_test tb_nova_x1_pc \
    rtl/fetch/nova_x1_pc.sv tb/tb_nova_x1_pc.sv

run_test tb_nova_x1_decoder \
    rtl/common/nova_pkg.sv rtl/decode/nova_x1_decoder.sv tb/tb_nova_x1_decoder.sv

run_test tb_nova_x1_execute \
    rtl/common/nova_pkg.sv rtl/decode/nova_x1_decoder.sv \
    rtl/registers/nova_x1_regfile.sv rtl/execution/nova_x1_alu.sv \
    rtl/execution/nova_x1_execute.sv tb/tb_nova_x1_execute.sv

run_test tb_nova_x1_core \
    rtl/common/nova_pkg.sv rtl/fetch/nova_x1_pc.sv \
    rtl/decode/nova_x1_decoder.sv rtl/registers/nova_x1_regfile.sv \
    rtl/execution/nova_x1_alu.sv rtl/execution/nova_x1_execute.sv \
    rtl/core/nova_x1_core.sv tb/tb_nova_x1_core.sv

echo "ALL NOVA X1 STARTER TESTS PASSED"
