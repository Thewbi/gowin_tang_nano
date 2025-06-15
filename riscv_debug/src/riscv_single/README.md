# Introduction

This folder contains a verilog version of the single cycle RISCV CPU
as outlined in the book Digital Design and Computer Architecture: RISC-V Edition
Sarah L. Harris and David Harris

https://pages.hmc.edu/harris/ddca/ddcarv.html

It has been converted from SystemVerilog to Verilog so that it can be simulated
on Windows using Icarus Verilog (which only supports Verilog).

# Compiling
cd into this folder

```
del riscv.vpp
C:\iverilog\bin\iverilog.exe -s top -o riscv.vvp top.v
C:\iverilog\bin\vvp.exe riscv.vvp
```

```
cd C:\Users\wolfg\dev\Java\verilog_formatter\src\test\resources\verilog_samples\harris_single_cycle_riscv_cpu
del riscv.vpp

C:\iverilog\bin\iverilog.exe -s adder -o riscv.vvp adder.v

C:\iverilog\bin\iverilog.exe -s aludec -o riscv.vvp aludec.v

C:\iverilog\bin\iverilog.exe -s maindec -o riscv.vvp maindec.v

C:\iverilog\bin\iverilog.exe -s controller -o riscv.vvp controller.v maindec.v aludec.v

C:\iverilog\bin\iverilog.exe -s dmem -o riscv.vvp dmem.v

C:\iverilog\bin\iverilog.exe -s extend -o riscv.vvp extend.v

C:\iverilog\bin\iverilog.exe -s flopenr -o riscv.vvp flopenr.v

C:\iverilog\bin\iverilog.exe -s flopr -o riscv.vvp flopr.v

C:\iverilog\bin\iverilog.exe -s imem -o riscv.vvp imem.v

C:\iverilog\bin\iverilog.exe -s mux2 -o riscv.vvp mux2.v

C:\iverilog\bin\iverilog.exe -s mux3 -o riscv.vvp mux3.v

C:\iverilog\bin\iverilog.exe -s regfile -o riscv.vvp regfile.v

C:\iverilog\bin\iverilog.exe -s alu -o riscv.vvp alu.v

C:\iverilog\bin\iverilog.exe -s datapath -o riscv.vvp datapath.v flopr.v aludec.v alu.v adder.v mux2.v mux3.v regfile.v extend.v

C:\iverilog\bin\iverilog.exe -s riscvsingle -o riscv.vvp riscvsingle.v controller.v datapath.v maindec.v flopr.v aludec.v alu.v adder.v mux2.v mux3.v regfile.v extend.v

C:\iverilog\bin\iverilog.exe -s top -o riscv.vvp top.v riscvsingle.v imem.v dmem.v controller.v datapath.v maindec.v flopr.v aludec.v alu.v adder.v mux2.v mux3.v regfile.v extend.v

C:\iverilog\bin\iverilog.exe -s testbench -o riscv.vvp testbench.v top.v riscvsingle.v imem.v dmem.v controller.v datapath.v maindec.v flopr.v aludec.v alu.v adder.v mux2.v mux3.v regfile.v extend.v

C:\iverilog\bin\vvp.exe riscv.vvp
```

In order to run the simulation with Icarus Verilog, run the testbench.s file as top-level module.
You have to execute the following statements to run the simulation:

```
cd C:\Users\wolfg\dev\Java\verilog_formatter\src\test\resources\verilog_samples\harris_single_cycle_riscv_cpu
del riscv.vpp

C:\iverilog\bin\iverilog.exe -s testbench -o riscv.vvp testbench.v top.v riscvsingle.v imem.v dmem.v controller.v datapath.v maindec.v flopr.v aludec.v alu.v adder.v mux2.v mux3.v regfile.v extend.v

C:\iverilog\bin\vvp.exe riscv.vvp
```