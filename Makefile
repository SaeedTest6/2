.PHONY: test lint clean

test:
	bash scripts/run_tests.sh

lint:
	verilator --lint-only -Wall --top-module nova_x1_alu rtl/common/nova_pkg.sv rtl/execution/nova_x1_alu.sv
	verilator --lint-only -Wall --top-module nova_x1_regfile rtl/registers/nova_x1_regfile.sv
	verilator --lint-only -Wall --top-module nova_x1_pc rtl/fetch/nova_x1_pc.sv

clean:
	rm -f sim/*
