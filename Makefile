.PHONY: test lint clean

test:
	bash scripts/run_tests.sh

lint:
	verilator --lint-only -Wall --top-module nova_x1_alu rtl/common/nova_pkg.sv rtl/execution/nova_x1_alu.sv
	verilator --lint-only -Wall --top-module nova_x1_regfile rtl/registers/nova_x1_regfile.sv
	verilator --lint-only -Wall --top-module nova_x1_pc rtl/fetch/nova_x1_pc.sv
	verilator --lint-only -Wall --top-module nova_x1_decoder rtl/common/nova_pkg.sv rtl/decode/nova_x1_decoder.sv
	verilator --lint-only -Wall -Wno-VARHIDDEN --top-module nova_x1_system rtl/common/nova_pkg.sv rtl/fetch/nova_x1_pc.sv rtl/memory/nova_x1_imem.sv rtl/memory/nova_x1_dmem.sv rtl/decode/nova_x1_decoder.sv rtl/registers/nova_x1_regfile.sv rtl/execution/nova_x1_alu.sv rtl/execution/nova_x1_execute.sv rtl/core/nova_x1_core.sv rtl/core/nova_x1_system.sv

clean:
	rm -f sim/*.vvp sim/tb_nova_x1_*
