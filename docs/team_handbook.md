# CẨM NANG DỰ ÁN MIPS PIPELINED 32-BIT — DÀNH CHO NHÓM

> **Đối tượng đọc:** Các thành viên chưa từng làm việc với Verilog.
> **Mục tiêu:** Đọc cẩm nang này xong là (1) hiểu hệ thống đang làm gì, (2) chạy được mô phỏng, (3) chụp được đủ ảnh, (4) có sẵn nội dung **PHẦN 4** để dán vào báo cáo.

---

## MỤC LỤC

- [A. KIẾN TRÚC TỔNG THỂ](#a-kiến-trúc-tổng-thể)
- [B. DATA FLOW QUA TỪNG TẦNG](#b-data-flow-qua-từng-tầng)
- [C. MỖI FILE LÀM GÌ TRONG KIẾN TRÚC?](#c-mỗi-file-làm-gì-trong-kiến-trúc)
- [D. HƯỚNG DẪN CHẠY MÔ PHỎNG](#d-hướng-dẫn-chạy-mô-phỏng)
- [E. NỘI DUNG PHẦN 4 BÁO CÁO (DÁN THẲNG VÀO)](#e-nội-dung-phần-4-báo-cáo-dán-thẳng-vào)
- [F. STEP-BY-STEP CHỤP TỪNG ẢNH GTKWave](#f-step-by-step-chụp-từng-ảnh-gtkwave)

---

## A. KIẾN TRÚC TỔNG THỂ

### A.1. Sơ đồ 5 tầng pipeline (mức cao)

```
       LẤY LỆNH    GIẢI MÃ   THỰC THI   TRUY CẬP   GHI LẠI
        (IF)        (ID)      (EX)      BỘ NHỚ      (WB)
                                        (MEM)

       ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐   ┌──────┐
  PC ─►│ IMEM │──►│CTRL  │──►│ ALU  │──►│ DMEM │──►│ MUX  │──┐
       │      │   │REGFL │   │FWDMX │   │      │   │      │  │
       └──────┘   │SEXT  │   │      │   └──────┘   └──────┘  │
                  └──────┘   └──────┘                         │
                                                              │
                  Register File ◄───────── ghi kết quả ◄──────┘

         ┌──┐       ┌──┐       ┌──┐       ┌──┐
         │IF│       │ID│       │EX│       │ME│
         │/ │       │/ │       │/ │       │M/│
         │ID│       │EX│       │ME│       │WB│
         └──┘       └──┘       │M │       └──┘
                                └──┘

         ▲          ▲          ▲          ▲
         │          │          │          │
         └──── Pipeline Registers (latch dữ liệu giữa các tầng) ────┘
```

Mỗi tầng làm việc với một lệnh khác nhau cùng lúc → 5 lệnh chạy song song. Pipeline Register là các "tủ chứa" chốt dữ liệu giữa hai tầng, đảm bảo dữ liệu của tầng trước không bị tầng sau ghi đè.

### A.2. Sơ đồ chi tiết (đối chiếu Patterson Hình 4.51 + 4.56)

```
                 ┌────────── HAZARD UNIT ──────┐
                 │ (phát hiện load-use stall)  │
                 │  - đóng băng PC             │
                 │  - đóng băng IF/ID          │
                 │  - chèn NOP vào ID/EX       │
                 └─┬───────────────┬───────────┘
                   ▼               ▼
              ┌────┐         ┌─────────┐
              │ PC │  ┌─────►│  IF/ID  │
              └─┬──┘  │      └────┬────┘
                │     │           │
                ▼     │           ▼
        ┌───────────┐ │      ┌───────────────────┐
        │  IMEM     │ │      │  ID stage:        │
        │ (1024w)   │─┘      │  - control_unit   │
        └───────────┘        │  - regfile (read) │
                             │  - sign_extend    │
                             └─────────┬─────────┘
                                       │
                                       ▼
                                 ┌─────────┐
                                 │  ID/EX  │
                                 └────┬────┘
                                      │
                       ┌──────────────┼──────────────┐
                       │              ▼              │
                       │      ┌───────────────┐      │
                       │      │  EX stage:    │      │
                       │      │  - ALU        │      │
                       │      │  - ALU control│      │
              FORWARD──┘      │  - Branch ?   │      │
              UNIT            └───────┬───────┘      │
              (chọn input            │              │
              cho ALU từ EX/MEM      ▼              │
              hoặc MEM/WB)     ┌─────────┐          │
                               │ EX/MEM  │          │
                               └────┬────┘          │
                                    │               │
                                    ▼               │
                              ┌──────────┐          │
                              │  DMEM    │          │
                              │ (1024w)  │          │
                              └────┬─────┘          │
                                   │                │
                                   ▼                │
                              ┌─────────┐           │
                              │ MEM/WB  │           │
                              └────┬────┘           │
                                   │                │
                                   ▼                │
                              ┌────────┐            │
                              │ MUX WB │────────────┘
                              └────┬───┘    (ghi vào regfile)
                                   ▼
                               regfile.write_data
```

### A.3. Mối quan hệ với Patterson

| Hình Patterson | Tương ứng trong dự án |
|----------------|------------------------|
| Hình 4.33 (5-stage skeleton) | Sơ đồ A.1 |
| Hình 4.51 (full pipeline + forwarding) | Sơ đồ A.2 (toàn bộ trừ Hazard Unit) |
| Hình 4.56 (pipeline + hazard detection) | Sơ đồ A.2 (đầy đủ) |
| Bảng 4.12 (ALU control encoding) | `mips_defines.vh` mục 4 + `alu.v` |
| Bảng 4.18 (Control signals per opcode) | `control_unit.v` |
| Hình 4.13 (ALU Control truth table) | `alu_control.v` |
| Hình 4.53 (Forwarding conditions) | `forwarding_unit.v` |

---

## B. DATA FLOW QUA TỪNG TẦNG

Mỗi tầng thực hiện một việc cụ thể. Bảng dưới đây mô tả "đầu vào" và "đầu ra" của mỗi tầng cho một lệnh thông thường.

### B.1. Tầng IF (Instruction Fetch — Lấy lệnh)

**Đầu vào:** thanh ghi `PC` (Program Counter — chỉ tới địa chỉ lệnh kế tiếp).
**Việc làm:** dùng `PC` để đọc lệnh 32-bit từ bộ nhớ lệnh.
**Đầu ra:** chốt vào IF/ID gồm `instruction[31:0]` và `PC+4`.

### B.2. Tầng ID (Instruction Decode — Giải mã)

**Đầu vào:** `instruction` từ IF/ID.
**Việc làm:**
1. Tách lệnh thành các trường: `opcode[31:26]`, `rs[25:21]`, `rt[20:16]`, `rd[15:11]`, `imm16[15:0]`, `funct[5:0]`.
2. `control_unit` đọc `opcode` → xuất ra 9 tín hiệu điều khiển (reg_dst, branch, mem_read, ...).
3. `regfile` đọc giá trị của 2 thanh ghi nguồn `rs`, `rt`.
4. `sign_extend` mở rộng `imm16` thành 32-bit có dấu.
5. `hazard_unit` kiểm tra xem có cần stall không (load-use hazard).

**Đầu ra:** chốt vào ID/EX gồm tất cả tín hiệu điều khiển + 2 giá trị thanh ghi + immediate + 3 địa chỉ thanh ghi (rs/rt/rd).

### B.3. Tầng EX (Execute — Thực thi)

**Đầu vào:** ID/EX.
**Việc làm:**
1. `forwarding_unit` quyết định 2 đầu vào ALU lấy từ đâu (regfile / EX/MEM / MEM/WB).
2. Mux `ALUSrc` chọn input thứ 2: thanh ghi hoặc immediate.
3. `alu_control` kết hợp `alu_op` (2-bit) + `funct` (6-bit) → mã ALU 4-bit.
4. `alu` thực hiện phép toán → `result` + cờ `zero`.
5. Tính địa chỉ rẽ nhánh: `PC+4 + (imm<<2)` (cho lệnh beq).
6. Mux `RegDst` chọn thanh ghi đích: `rd` (R-type) hoặc `rt` (I-type).

**Đầu ra:** chốt vào EX/MEM gồm `alu_result`, `zero`, write_data (cho sw), write_reg.

### B.4. Tầng MEM (Memory Access — Truy cập bộ nhớ)

**Đầu vào:** EX/MEM.
**Việc làm:**
- Nếu `mem_write=1` (lệnh sw): ghi write_data vào DMEM tại địa chỉ alu_result.
- Nếu `mem_read=1` (lệnh lw): đọc DMEM tại địa chỉ alu_result → `read_data`.
- Các lệnh khác: không làm gì với bộ nhớ.

**Đầu ra:** chốt vào MEM/WB gồm `alu_result`, `read_data`, `write_reg`, các tín hiệu WB.

### B.5. Tầng WB (Write Back — Ghi lại)

**Đầu vào:** MEM/WB.
**Việc làm:** Mux `MemtoReg` chọn dữ liệu ghi vào thanh ghi đích:
- Nếu là lw: ghi `read_data` (giá trị vừa đọc từ DMEM).
- Còn lại: ghi `alu_result`.
**Đầu ra:** dữ liệu được ghi vào `regfile` tại địa chỉ `write_reg` (chỉ khi `reg_write=1`).

---

## C. MỖI FILE LÀM GÌ TRONG KIẾN TRÚC?

Tổng cộng 11 file Verilog + 1 file header. Bảng dưới mô tả vai trò ngắn gọn để nhóm tra cứu nhanh.

### C.1. Bảng tổng quan

| File | Loại | Thuộc tầng nào | Chức năng 1 câu |
|------|------|----------------|------------------|
| [src/mips_defines.vh](../src/mips_defines.vh) | Header | Toàn hệ thống | Định nghĩa hằng số: opcode, funct, ALU code, kích thước. |
| [src/inst_memory.v](../src/inst_memory.v) | ROM | IF | Bộ nhớ lệnh 1024 word, nạp `fibonacci.hex` lúc khởi tạo. |
| [src/control_unit.v](../src/control_unit.v) | Combinational | ID | Đọc 6-bit opcode → 9 tín hiệu điều khiển. |
| [src/regfile.v](../src/regfile.v) | Sequential + Comb | ID (đọc) + WB (ghi) | 32 thanh ghi 32-bit, ghi negedge / đọc tổ hợp. |
| [src/sign_extend.v](../src/sign_extend.v) | Combinational | ID | Mở rộng dấu 16-bit → 32-bit. |
| [src/hazard_unit.v](../src/hazard_unit.v) | Combinational | ID | Phát hiện load-use, sinh tín hiệu `stall`. |
| [src/forwarding_unit.v](../src/forwarding_unit.v) | Combinational | EX | Sinh mã chọn mux cho 2 input của ALU. |
| [src/alu_control.v](../src/alu_control.v) | Combinational | EX | ALUOp + funct → 4-bit ALU control. |
| [src/alu.v](../src/alu.v) | Combinational | EX | Cộng/trừ/and/or/slt/nor 32-bit, ra cờ `zero`. |
| [src/data_memory.v](../src/data_memory.v) | Sequential + Comb | MEM | RAM 1024 word, ghi posedge / đọc tổ hợp. |
| [src/pipeline_regs.v](../src/pipeline_regs.v) | Sequential | IF↔ID, ID↔EX, EX↔MEM, MEM↔WB | 4 thanh ghi chốt có stall/flush. |
| [src/mips_top.v](../src/mips_top.v) | Cấu trúc | Toàn hệ thống | Nối dây tất cả module, chứa PC. |

### C.2. Giải thích sâu hơn từng file

#### `mips_defines.vh` — TỪ ĐIỂN CHUNG
Chứa các macro hằng số (ví dụ `` `OP_LW = 6'b100011 ``). Mỗi file `.v` đều `` `include `` file này để không phải nhớ con số raw. Khi sửa hằng số → chỉ sửa 1 chỗ.

#### `inst_memory.v` — BỘ NHỚ LỆNH (IF)
Tương đương ROM trong vi xử lý thật. Lúc bắt đầu mô phỏng, lệnh `$readmemh` nạp file `asm/fibonacci.hex` vào mảng `memory[0:1023]`. Khi `PC` thay đổi, output `instruction` đổi theo (đọc tổ hợp).

#### `control_unit.v` — BỘ NÃO ĐIỀU KHIỂN (ID)
Hộp đen nhỏ với 1 input (`opcode`) và 9 output. Tùy theo lệnh là R-type, lw, sw, beq, addi, j → bật các "công tắc" khác nhau. Ví dụ lệnh `lw`: bật `mem_read=1, mem_to_reg=1, reg_write=1, alu_src=1, alu_op=00`.

#### `regfile.v` — TẬP THANH GHI 32×32 (ID/WB)
32 ô nhớ, mỗi ô 32-bit. Có 2 cổng đọc (cho rs, rt) và 1 cổng ghi (cho rd). Đặc biệt: ghi xảy ra ở **cạnh xuống** (negedge clk) để tầng WB có thể ghi xong trước nửa chu kỳ, kịp cho tầng ID đọc trong nửa chu kỳ sau. Thanh ghi $0 (zero) luôn = 0, không cho ghi.

#### `sign_extend.v` — MỞ RỘNG DẤU (ID)
Một dòng code: `imm_ext = {{16{imm_in[15]}}, imm_in};`. Nếu bit 15 = 1 (số âm) → thêm 16 bit 1 phía trước. Nếu = 0 → thêm 16 bit 0. Cần cho lệnh addi, lw, sw, beq.

#### `hazard_unit.v` — PHÁT HIỆN STALL (ID)
Theo dõi: "Lệnh đang trong EX có phải lw không, và nếu có thì lệnh kế tiếp (đang trong ID) có dùng thanh ghi mà lw sắp ghi không?". Nếu cả 2 đúng → bật `stall=1` để đóng băng pipeline 1 chu kỳ.

#### `forwarding_unit.v` — CHUYỂN TIẾP DỮ LIỆU (EX)
Khi 2 lệnh liên tiếp cần dùng cùng kết quả (ví dụ `add $t0, $t1, $t2` rồi `add $t3, $t0, $t4`), thay vì đợi $t0 được ghi vào regfile (sau 2 chu kỳ), forwarding lấy thẳng kết quả ALU từ EX/MEM hoặc MEM/WB đẩy ngược về input ALU. Output: `forward_a[1:0]`, `forward_b[1:0]`:
- `00` = lấy từ regfile (bình thường)
- `10` = lấy từ EX/MEM (1 lệnh trước)
- `01` = lấy từ MEM/WB (2 lệnh trước)

#### `alu_control.v` — GIẢI MÃ ALU (EX)
Có 2 input: `alu_op[1:0]` (từ control_unit) và `funct[5:0]` (lấy từ 6 bit cuối của lệnh R-type). Output 4-bit `alu_ctrl` đưa vào ALU. Bảng truth:
- alu_op=00 → ADD (cho lw/sw/addi tính địa chỉ)
- alu_op=01 → SUB (cho beq so sánh)
- alu_op=10 → giải mã `funct`: ADD/SUB/AND/OR/SLT

#### `alu.v` — BỘ TÍNH TOÁN (EX)
Nhận 2 toán hạng 32-bit và 1 mã điều khiển 4-bit, xuất kết quả 32-bit + cờ `zero`. Cờ `zero` dùng cho lệnh `beq` (nếu kết quả phép trừ = 0 thì 2 thanh ghi bằng nhau).

#### `data_memory.v` — BỘ NHỚ DỮ LIỆU (MEM)
Tương đương RAM 1024 word. Ghi đồng bộ (posedge clk khi `mem_write=1`), đọc tổ hợp (khi `mem_read=1`).

#### `pipeline_regs.v` — 4 THANH GHI CHỐT
Cốt lõi của pipeline. Mỗi chu kỳ, ở cạnh lên xung nhịp:
- IF/ID chốt lệnh mới từ IF.
- ID/EX chốt tín hiệu điều khiển + dữ liệu từ ID.
- EX/MEM chốt kết quả ALU từ EX.
- MEM/WB chốt dữ liệu cuối cùng từ MEM.

Có chân `stall_if_id`, `flush_if_id`, `flush_id_ex` để hazard_unit và control hazard điều khiển.

#### `mips_top.v` — TÍCH HỢP HỆ THỐNG
File "tổng đài". Khai báo wires nối các module với nhau, chứa thanh ghi `PC`, mux chọn PC kế tiếp (branch / jump / stall / PC+4), và logic flush khi rẽ nhánh.

---

## D. HƯỚNG DẪN CHẠY MÔ PHỎNG

### D.1. Yêu cầu cài đặt
- Icarus Verilog (đã có tại `D:\iverilog\bin\`)
- GTKWave (đã có tại `D:\iverilog\gtkwave\bin\`)

Nếu chưa có: tải bộ cài tại http://bleyer.org/icarus/ (gồm cả iverilog + gtkwave).

### D.2. Quy trình chạy 1 lệnh duy nhất

Mở **PowerShell** hoặc **CMD**, sau đó:

```powershell
cd D:\Desktop\mips32-pipelined-cpu
.\scripts\run_sim.bat
```

Lệnh trên sẽ tự động:
1. Compile toàn bộ source Verilog bằng `iverilog`.
2. Chạy mô phỏng bằng `vvp`, sinh file `waves\mips_sim.vcd`.
3. Mở GTKWave với layout cấu hình sẵn.

### D.3. Kiểm tra kết quả mô phỏng đúng

Sau khi chạy, terminal phải in ra **đúng** đoạn này:

```
=== Simulation complete ===
PC = 54
Registers (t0-t4):
  $t0 = 0
  $t1 = 1
  $t2 = 1
  $t3 = 1
  $t4 = 2
Data memory (Fibonacci sequence):
  mem[0]  = 0 (expect 0)
  mem[1]  = 1 (expect 1)
  mem[2]  = 1 (expect 1)
  mem[3]  = 2 (expect 2)
  mem[4]  = 3 (expect 3)
  mem[5]  = 5 (expect 5)
  mem[6]  = 8 (expect 8)
  mem[7]  = 13 (expect 13)
```

Nếu thấy đúng → CPU chạy đúng. Tiếp tục mở GTKWave và làm theo PHẦN F.

### D.4. Lưu ý
- **Cảnh báo** `Not enough words in the file for the requested range [0:1023]` là bình thường, vì chương trình Fibonacci chỉ có 21 lệnh trong khi bộ nhớ có 1024 ô. Bỏ qua cảnh báo này.
- Phải chạy lệnh từ **thư mục gốc** `mips32-pipelined-cpu`, không phải từ trong `scripts\`.

---

## E. NỘI DUNG PHẦN 4 BÁO CÁO (DÁN THẲNG VÀO)

> **Hướng dẫn:** Sao chép các đoạn dưới đây vào báo cáo. Chỗ `[CHÈN ẢNH X]` thay bằng ảnh tương ứng đã chụp theo PHẦN F. Có thể chỉnh sửa giọng văn cho khớp với phong cách viết chung của nhóm.

---

### PHẦN 4. THỰC NGHIỆM VÀ MÔ PHỎNG

#### 4.1. Công cụ sử dụng

Nhóm triển khai thiết kế CPU MIPS 32-bit Pipelined trên ngôn ngữ mô tả phần cứng **Verilog** theo chuẩn IEEE 1364-2001. Chuỗi công cụ bao gồm:

| Công cụ | Phiên bản | Vai trò |
|---------|-----------|---------|
| Icarus Verilog (iverilog) | 12.0 | Biên dịch mã nguồn Verilog thành dạng thực thi (`sim.out`) |
| Icarus VVP | 12.0 | Thực thi mô phỏng, sinh file Value Change Dump (`.vcd`) |
| GTKWave | 3.3 | Hiển thị và phân tích dạng sóng |
| MARS MIPS Simulator | 4.5 | Dịch mã hợp ngữ MIPS sang mã máy (`.hex`) |

Toàn bộ thiết kế được tổ chức thành 11 module Verilog + 1 file header hằng số, theo cấu trúc:

```
src/
├── mips_defines.vh        # Hằng số (opcode, funct, ALU code)
├── alu.v                  # Bộ tính toán ALU
├── alu_control.v          # Giải mã điều khiển ALU
├── regfile.v              # 32 thanh ghi 32-bit
├── sign_extend.v          # Mở rộng dấu 16→32 bit
├── control_unit.v         # Bộ điều khiển chính
├── inst_memory.v          # Bộ nhớ lệnh ROM
├── data_memory.v          # Bộ nhớ dữ liệu RAM
├── forwarding_unit.v      # Đơn vị chuyển tiếp dữ liệu
├── hazard_unit.v          # Đơn vị phát hiện xung đột
├── pipeline_regs.v        # 4 thanh ghi pipeline (IF/ID, ID/EX, EX/MEM, MEM/WB)
└── mips_top.v             # Module tích hợp mức cao nhất
```

#### 4.2. Kịch bản kiểm thử (Testbench)

##### 4.2.1. Chương trình kiểm thử — Dãy Fibonacci

Để kiểm tra tính đúng đắn của tất cả các loại lệnh và cơ chế giải quyết xung đột, nhóm xây dựng chương trình tính 8 số Fibonacci đầu tiên (`F(0)` đến `F(7) = 0, 1, 1, 2, 3, 5, 8, 13`), lưu kết quả vào bộ nhớ dữ liệu, sau đó nạp lại các giá trị vừa lưu để chủ động kích hoạt các tình huống xung đột dữ liệu.

Mã hợp ngữ MIPS của chương trình (`asm/fibonacci.s`):

```asm
# ---- Khởi tạo ----
    addi $t3, $zero, 0      # ptr = 0
    addi $t4, $zero, 32     # end = 32
    addi $t0, $zero, 0      # F(0) = 0
    addi $t1, $zero, 1      # F(1) = 1
    sw   $t0, 0($t3)        # mem[0] = 0
    sw   $t1, 4($t3)        # mem[4] = 1
    addi $t3, $t3,  8       # ptr = 8

# ---- Vòng lặp tính F(2)..F(7) ----
loop:
    add  $t2, $t0, $t1      # F(n) = F(n-2) + F(n-1)
    sw   $t2, 0($t3)        # mem[ptr] = F(n)
    add  $t0, $t1, $zero    # F(n-2) = F(n-1)
    add  $t1, $t2, $zero    # F(n-1) = F(n)
    addi $t3, $t3, 4        # ptr += 4
    beq  $t3, $t4, done     # if ptr == 32 → exit
    j    loop

# ---- Kiểm tra: lw + add liên tiếp → kích hoạt Load-Use Stall ----
done:
    lw   $t0, 0($zero)      # tải F(0)
    add  $t2, $t0, $t1      # LOAD-USE HAZARD trên $t0
    lw   $t1, 4($zero)      # tải F(1)
    add  $t2, $t0, $t1      # LOAD-USE HAZARD trên $t1
    lw   $t3, 8($zero)      # tải F(2)
    add  $t4, $t3, $t2      # LOAD-USE HAZARD trên $t3

halt:
    j    halt               # halt vô hạn
```

Chương trình sử dụng đủ 6 loại lệnh đại diện: **R-type** (`add`), **I-type arithmetic** (`addi`), **I-type memory** (`lw`, `sw`), **I-type branch** (`beq`), và **J-type** (`j`).

##### 4.2.2. Cấu trúc testbench

File `tb/mips_tb.v` thực hiện:
1. Sinh tín hiệu xung nhịp `clk` chu kỳ 10 ns (tần số 100 MHz).
2. Phát tín hiệu `reset` mức cao trong 3 chu kỳ đầu để khởi tạo PC = 0 và xóa toàn bộ thanh ghi.
3. Chạy mô phỏng 300 chu kỳ (đủ để chương trình thực thi xong và đi vào vòng halt).
4. Xuất file `waves/mips_sim.vcd` thông qua hệ thống `$dumpfile`/`$dumpvars` để phân tích dạng sóng.
5. Hiển thị kết quả cuối cùng của các thanh ghi `$t0..$t4` và 8 ô bộ nhớ đầu tiên để đối chiếu.

##### 4.2.3. Kết quả thực thi chương trình

Sau khi chạy `scripts\run_sim.bat`, terminal in ra:

```
=== Simulation complete ===
Data memory (Fibonacci sequence):
  mem[0] = 0  (expect 0)    ✓
  mem[1] = 1  (expect 1)    ✓
  mem[2] = 1  (expect 1)    ✓
  mem[3] = 2  (expect 2)    ✓
  mem[4] = 3  (expect 3)    ✓
  mem[5] = 5  (expect 5)    ✓
  mem[6] = 8  (expect 8)    ✓
  mem[7] = 13 (expect 13)   ✓
```

Cả 8 giá trị Fibonacci đều chính xác → chứng minh CPU thực thi đúng toàn bộ luồng instruction, bao gồm cả các trường hợp có data hazard, control hazard (lệnh beq, j) đã được xử lý đúng.

#### 4.3. Phân tích kết quả mô phỏng

##### 4.3.1. Tổng quan dạng sóng

Hình dưới đây cho thấy 5 tầng pipeline hoạt động song song trong vòng lặp Fibonacci. Quan sát `pc` (Program Counter), `if_id_instr`, `id_ex_alu_op`, `ex_mem_alu_result`, `mem_wb_write_reg` để thấy mỗi chu kỳ pipeline xử lý đồng thời 5 lệnh khác nhau.

**[CHÈN ẢNH 1: Tổng quan dạng sóng — pipeline 5 tầng hoạt động]**

##### 4.3.2. Cơ chế Forwarding hoạt động đúng

Trong vòng lặp Fibonacci, mỗi iteration có chuỗi lệnh:
```
add $t2, $t0, $t1     # lệnh A — sinh ra $t2
sw  $t2, 0($t3)       # lệnh B — dùng $t2 ngay sau đó (cần forward từ EX/MEM)
add $t0, $t1, $zero   # lệnh C
add $t1, $t2, $zero   # lệnh D — dùng $t2 (cần forward từ MEM/WB)
```

Lệnh B cần kết quả $t2 vừa được lệnh A tính xong → Forwarding Unit phát `forward_b = 2'b10` (forward từ EX/MEM). Hình sau cho thấy thời điểm đó:

**[CHÈN ẢNH 2: Forwarding EX-EX — forward_a hoặc forward_b = 10]**

Tương tự, lệnh D dùng $t2 nhưng giữa A và D có 2 lệnh khác → forward từ MEM/WB (`forward_b = 2'b01`):

**[CHÈN ẢNH 3: Forwarding MEM-EX — forward_a hoặc forward_b = 01]**

Nhờ Forwarding, **không cần stall** trong các trường hợp data hazard giữa các lệnh R-type liên tiếp, giữ CPI ≈ 1.

##### 4.3.3. Cơ chế Load-Use Stall hoạt động đúng

Trong phần "verification" sau vòng lặp, chuỗi lệnh:
```
lw  $t0, 0($zero)     # lệnh A — đọc bộ nhớ vào $t0 (kết quả chỉ có ở tầng MEM)
add $t2, $t0, $t1     # lệnh B — cần $t0 ngay lập tức ở tầng EX
```

Đây là **Load-Use Hazard điển hình**. Forwarding không thể giải quyết vì kết quả lw chỉ có sau tầng MEM, trong khi lệnh B cần dữ liệu ở tầng EX (1 chu kỳ trước). Hazard Detection Unit phát hiện điều này và:
1. Đóng băng `PC` (giữ nguyên giá trị).
2. Đóng băng IF/ID (không nhận lệnh mới).
3. Chèn bong bóng (NOP) vào ID/EX.

Sau 1 chu kỳ stall, kết quả lw đã ở tầng MEM/WB → Forwarding tiếp tục đẩy về EX cho lệnh add. Hình sau cho thấy tín hiệu `stall = 1`:

**[CHÈN ẢNH 4: Load-Use Stall — stall = 1, PC đóng băng]**

##### 4.3.4. Đo chu kỳ xung nhịp

Đo khoảng cách giữa 2 cạnh lên liên tiếp của `clk` trong GTKWave:

**[CHÈN ẢNH 5: Đo cycle time = 10 ns]**

Chu kỳ xung nhịp mô phỏng = **10 ns** (tương đương tần số 100 MHz). Đây là tham số đầu vào cho mục 5.1 — phân tích CPI và so sánh với single-cycle.

##### 4.3.5. Kết luận phần thực nghiệm

Toàn bộ CPU MIPS Pipelined 5 tầng đã được kiểm chứng thành công với chương trình Fibonacci. Cả 3 yêu cầu cốt lõi đều đạt:
- ✓ Pipeline 5 tầng hoạt động song song.
- ✓ Forwarding xử lý đúng các data hazard giữa lệnh R-type liên tiếp.
- ✓ Hazard Detection chèn stall đúng khi gặp load-use, không gây sai dữ liệu.
- ✓ Branch (beq) và Jump (j) được flush đúng cách, không sinh lệnh "ma".

---

## F. STEP-BY-STEP CHỤP TỪNG ẢNH GTKWave

> **Trước khi bắt đầu:** Đã chạy xong `scripts\run_sim.bat`, GTKWave đã mở với file `mips_sim.vcd`.

### F.0. Thao tác cơ bản GTKWave (cần biết trước)

| Thao tác | Phím tắt / Cách làm |
|----------|---------------------|
| Zoom in | `Ctrl + +`, hoặc lăn chuột lên (giữ Ctrl) |
| Zoom out | `Ctrl + -`, hoặc lăn chuột xuống |
| Fit toàn bộ | `Ctrl + F` (View → Zoom → Fit) |
| Đặt cursor (đường vàng) | Click chuột trái vào dạng sóng |
| Đặt marker thứ 2 | Click chuột giữa, hoặc menu Markers |
| Xuất ảnh PNG | File → Write PNG... (hoặc chụp màn hình `Win + Shift + S`) |
| Tìm tín hiệu | Trong cột Signal: gõ tên vào ô Filter |

### F.1. ẢNH 1 — Tổng quan dạng sóng pipeline 5 tầng

**Mục đích:** Cho thấy 5 lệnh khác nhau chạy song song qua 5 tầng.

**Thao tác:**
1. Nhấn `Ctrl + F` để fit toàn bộ.
2. Phóng to vào vùng thời gian từ **80 ns đến 200 ns** (khoảng đầu vòng lặp Fibonacci, sau khi reset đã off và pipeline đã đầy).
3. Trong layout đã có sẵn các nhóm tín hiệu — đảm bảo nhìn thấy:
   - `pc[31:0]`
   - `if_id_instr[31:0]`
   - `id_ex_alu_op[1:0]`
   - `ex_mem_alu_result[31:0]`
   - `mem_wb_write_reg[4:0]`
   - `clk`
4. **Lưu ảnh:** File → Write PNG → đặt tên `fig4_1_pipeline_overview.png`.

**Caption đề xuất:**
> Hình 4.1: Tổng quan hoạt động pipeline 5 tầng trong vòng lặp Fibonacci. Tại mỗi cạnh lên xung nhịp, 5 lệnh khác nhau cùng được xử lý ở 5 tầng IF/ID/EX/MEM/WB.

### F.2. ẢNH 2 — Forwarding EX-EX (forward = 10)

**Mục đích:** Chứng minh Forwarding Unit phát mã `2'b10` khi 2 lệnh liên tiếp có data hazard.

**Thao tác:**
1. Phóng to vào vùng **120 ns đến 280 ns** (trong vòng lặp, sau iteration đầu tiên).
2. Tìm trong cột Signal các tín hiệu (đã có sẵn trong layout):
   - `forward_a[1:0]`
   - `forward_b[1:0]`
3. Quan sát các thời điểm mà `forward_a` hoặc `forward_b` = `2` (= 2'b10, hiển thị là `2` ở dạng decimal). Các sự kiện forwarding EX-EX xảy ra tại các mốc khoảng **125, 165, 205, 245 ns**.
4. Click chuột trái vào một trong các thời điểm đó để đặt cursor — góc trên hiện thời gian chính xác.
5. **Lưu ảnh:** `fig4_2_forwarding_ex_mem.png`.

**Caption đề xuất:**
> Hình 4.2: Forwarding từ EX/MEM về EX stage. Tín hiệu `forward_b = 10` cho thấy giá trị `$t2` vừa được tính xong bởi lệnh `add` (đang ở EX/MEM) được forward thẳng về làm input cho lệnh `sw` (đang ở EX). Nhờ vậy không cần stall.

### F.3. ẢNH 3 — Forwarding MEM-EX (forward = 01)

**Mục đích:** Chứng minh forward từ MEM/WB (2 lệnh trước).

**Thao tác:**
1. Phóng to vào vùng **600 ns đến 700 ns** (trong phần verification, ngay sau các load-use stall, forwarding MEM-EX hoạt động để đưa kết quả lw về lệnh add).
2. Tìm thời điểm `forward_a` hoặc `forward_b` = `1` (= 2'b01). Các mốc xuất hiện: **615 ns (fwd_a), 645 ns (fwd_b), 675 ns (fwd_a)**.
3. Đặt cursor, lưu ảnh `fig4_3_forwarding_mem_wb.png`.

> **Lưu ý:** Vùng 80-130 ns cũng có forwarding=01 nhưng chỉ ngắn 1-2 chu kỳ. Vùng 600-700 ns rõ ràng hơn vì xảy ra ngay sau stall.

**Caption đề xuất:**
> Hình 4.3: Forwarding từ MEM/WB về EX stage. Tín hiệu `forward_b = 01` cho thấy giá trị thanh ghi vừa được ghi lại ở tầng WB được forward về EX cho lệnh đang thực thi, dùng cho trường hợp khoảng cách 2 lệnh giữa producer và consumer.

### F.4. ẢNH 4 — Load-Use Stall

**Mục đích:** Chứng minh Hazard Unit phát `stall = 1` khi gặp lw + add liên tiếp.

**Thao tác:**
1. Phóng to vào vùng **580 ns đến 680 ns** (phần "verification" sau loop — chỗ có 3 lệnh lw kế tiếp 3 lệnh add phụ thuộc).
2. Tìm các tín hiệu:
   - `stall`
   - `pc[31:0]`
   - `if_id_instr[31:0]`
   - `flush_id_ex`
3. Quan sát 3 sự kiện stall liên tiếp tại các mốc **595 ns, 625 ns, 655 ns** — mỗi lần `stall = 1` đúng 1 chu kỳ (10 ns). Trong các chu kỳ stall đó, `pc` không đổi (đóng băng) và `flush_id_ex = 1` (chèn bong bóng vào ID/EX).
4. Đặt cursor tại 595 ns để chụp sự kiện stall đầu tiên rõ nét nhất, hoặc giữ toàn vùng 580-680 ns để thấy cả 3 lần stall trong cùng 1 ảnh.
5. Lưu ảnh `fig4_4_load_use_stall.png`.

**Caption đề xuất:**
> Hình 4.4: Cơ chế Load-Use Stall. Sau lệnh `lw $t0, 0($zero)`, lệnh kế tiếp `add $t2, $t0, $t1` cần ngay $t0. Hazard Unit phát hiện điều này, kéo `stall = 1` một chu kỳ. Trong chu kỳ stall, `pc` đóng băng, `if_id_instr` đóng băng, và `flush_id_ex = 1` chèn NOP vào ID/EX để chờ kết quả lw.

### F.5. ẢNH 5 — Đo Cycle Time

**Mục đích:** Đo và xác nhận chu kỳ xung nhịp = 10 ns.

**Thao tác:**
1. Phóng to **rất sát** vào tín hiệu `clk` sao cho nhìn thấy rõ 3-4 cạnh lên (ví dụ vùng 100-140 ns).
2. Click chuột trái vào **cạnh lên đầu tiên** → cursor vàng đứng ở thời điểm T1, GTKWave hiện T1 trên thanh thời gian.
3. Click chuột phải vào **cạnh lên kế tiếp** → marker thứ 2 ở T2. (Hoặc menu: `Markers → Drop named marker`.)
4. Khoảng cách (T2 - T1) hiện ngay phía trên = 10 ns.
5. Lưu ảnh `fig4_5_cycle_time.png`.

**Caption đề xuất:**
> Hình 4.5: Đo chu kỳ xung nhịp. Khoảng cách giữa 2 cạnh lên liên tiếp của `clk` là 10 ns → tần số mô phỏng = 100 MHz.

### F.6. Tổng kết các ảnh cần có cho báo cáo

| Tên file | Vùng thời gian | Tín hiệu chính |
|----------|----------------|-----------------|
| `fig4_1_pipeline_overview.png` | 80–280 ns | `pc`, `if_id_instr`, `id_ex_alu_op`, `ex_mem_alu_result`, `mem_wb_write_reg` |
| `fig4_2_forwarding_ex_mem.png` | 120–280 ns (mốc 125/165/205/245 ns) | `forward_a` hoặc `forward_b` = 2 |
| `fig4_3_forwarding_mem_wb.png` | 600–700 ns (mốc 615/645/675 ns) | `forward_a` hoặc `forward_b` = 1 |
| `fig4_4_load_use_stall.png` | 580–680 ns (mốc 595/625/655 ns) | `stall = 1`, `pc` đóng băng |
| `fig4_5_cycle_time.png` | bất kỳ vùng nào có clk | `clk`, 2 marker đo 10 ns |

Lưu tất cả ảnh vào thư mục `docs/figures/` (tự tạo) để có chỗ tham chiếu khi viết báo cáo.

---

## PHỤ LỤC: KHI GẶP LỖI

| Lỗi | Cách xử lý |
|-----|-----------|
| `iverilog: command not found` | Mở `scripts\run_sim.bat` — kiểm tra biến `IVERILOG` trỏ đúng đường dẫn cài đặt. |
| `'-o': No such file or directory` | Đang chạy script từ trong `scripts\`, phải `cd ..` trước. |
| GTKWave không có signal nào | File → Read Save File → chọn `waves/debug_layout.gtkw`. |
| `mem[0..7]` không ra Fibonacci đúng | Kiểm tra `asm/fibonacci.hex` còn nguyên nội dung, không bị xóa. Recompile lại. |
| GTKWave hiện toàn bit `x` | Reset chưa được kích hoạt → kiểm tra phần đầu của waveform xem `reset` có lên 1 trong 30ns đầu không. |

---

*Cẩm nang này được biên soạn bởi Tự (nhóm trưởng) cho team MI4344. Mọi câu hỏi liên hệ Tự trực tiếp, không gửi qua Zalo lẻ tẻ.*
