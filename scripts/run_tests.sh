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

echo "ALL NOVA X1 STARTER TESTS PASSED"
