@echo off
REM ============================================================
REM  run_sim.bat  —  Compile and simulate the MIPS pipeline CPU
REM  Must be run from the project root directory:
REM      cd mips32-pipelined-cpu
REM      scripts\run_sim.bat
REM ============================================================

echo [1/3] Compiling Verilog sources...

iverilog -g2001 -I src ^
    src/mips_defines.vh ^
    src/alu.v ^
    src/alu_control.v ^
    src/regfile.v ^
    src/sign_extend.v ^
    src/control_unit.v ^
    src/inst_memory.v ^
    src/data_memory.v ^
    src/forwarding_unit.v ^
    src/hazard_unit.v ^
    src/pipeline_regs.v ^
    src/mips_top.v ^
    tb/mips_tb.v ^
    -o sim.out

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Compilation failed.
    exit /b 1
)

echo [2/3] Running simulation...
vvp sim.out

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Simulation failed.
    exit /b 1
)

echo [3/3] Opening GTKWave...
gtkwave waves/mips_sim.vcd waves/debug_layout.gtkw

echo Done.
