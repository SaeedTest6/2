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
run_test tb_nova_x1_regfile rtl/registers/nova_x1_regfile.sv tb/tb_nova_x1_regfile.sv
run_test tb_nova_x1_pc rtl/fetch/nova_x1_pc.sv tb/tb_nova_x1_pc.sv
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
run_test tb_nova_x1_branch \
    rtl/common/nova_pkg.sv rtl/fetch/nova_x1_pc.sv \
    rtl/decode/nova_x1_decoder.sv rtl/registers/nova_x1_regfile.sv \
    rtl/execution/nova_x1_alu.sv rtl/execution/nova_x1_execute.sv \
    rtl/core/nova_x1_core.sv tb/tb_nova_x1_branch.sv
run_test tb_nova_x1_branch_compare \
    rtl/common/nova_pkg.sv rtl/fetch/nova_x1_pc.sv \
    rtl/decode/nova_x1_decoder.sv rtl/registers/nova_x1_regfile.sv \
    rtl/execution/nova_x1_alu.sv rtl/execution/nova_x1_execute.sv \
    rtl/core/nova_x1_core.sv tb/tb_nova_x1_branch_compare.sv
run_test tb_nova_x1_jump \
    rtl/common/nova_pkg.sv rtl/fetch/nova_x1_pc.sv \
    rtl/decode/nova_x1_decoder.sv rtl/registers/nova_x1_regfile.sv \
    rtl/execution/nova_x1_alu.sv rtl/execution/nova_x1_execute.sv \
    rtl/core/nova_x1_core.sv tb/tb_nova_x1_jump.sv
run_test tb_nova_x1_imem rtl/memory/nova_x1_imem.sv tb/tb_nova_x1_imem.sv
run_test tb_nova_x1_system \
    rtl/common/nova_pkg.sv rtl/fetch/nova_x1_pc.sv \
    rtl/memory/nova_x1_imem.sv rtl/decode/nova_x1_decoder.sv \
    rtl/registers/nova_x1_regfile.sv rtl/execution/nova_x1_alu.sv \
    rtl/execution/nova_x1_execute.sv rtl/core/nova_x1_core.sv \
    rtl/core/nova_x1_system.sv tb/tb_nova_x1_system.sv
run_test tb_nova_x1_control_flow_system \
    rtl/common/nova_pkg.sv rtl/fetch/nova_x1_pc.sv \
    rtl/memory/nova_x1_imem.sv rtl/decode/nova_x1_decoder.sv \
    rtl/registers/nova_x1_regfile.sv rtl/execution/nova_x1_alu.sv \
    rtl/execution/nova_x1_execute.sv rtl/core/nova_x1_core.sv \
    rtl/core/nova_x1_system.sv tb/tb_nova_x1_control_flow_system.sv

echo "ALL NOVA X1 STARTER TESTS PASSED"
