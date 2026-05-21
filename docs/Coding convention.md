# QUY CHUẨN LẬP TRÌNH & GIAO THỨC GIAO TIẾP (OFFICIAL)

**Dự án:** Thiết kế bộ vi xử lý MIPS 32-bit Pipelined 5 tầng (MI4344)  
**Đối tượng:** Thành viên nhóm (An, Hiếu, Tự, Dung)  
**Trạng thái:** Tài liệu bắt buộc tuân thủ cấp độ cao nhất.## 1. QUY TẮC CHUNG (GENERAL CODING STYLE)

- **Ngôn ngữ:** Verilog-2001 (IEEE 1364-2001)
- **Thụt lề (Indentation):** Sử dụng 4 spaces (không dùng tab)
- **Cấu trúc File:** Mỗi file .v chỉ chứa duy nhất một module. Tên file phải trùng tên module (Ví dụ: alu.v chứa module alu)

### Đặt tên (Naming Convention)
- Sử dụng snake_case (chữ thường, gạch dưới). Ví dụ: alu_result, reg_write
- TUYỆT ĐỐI KHÔNG dùng CamelCase (như AluResult)

### Clock & Reset
- **Clock:** Luôn đặt tên là clk, kích hoạt cạnh lên (posedge clk)
- **Reset:** Luôn đặt tên là reset, kích hoạt bất đồng bộ, mức cao (posedge reset)
- **Vị trí:** clk và reset luôn là 2 cổng đầu tiên trong mọi module

### Kích thước tín hiệu
- **Dữ liệu/Lệnh:** [31:0]
- **Địa chỉ Thanh ghi (rs, rt, rd):** [4:0]
- **Opcode/Funct:** [6:0]## 2. QUY TẮC SỬ DỤNG HẰNG SỐ (MANDATORY MACROS)

Để tránh hiện tượng "Magic Numbers" (nhập số cứng), dự án sử dụng file từ điển chung tại `src/mips_defines.vh`.

**Luật chuẩn:**
- Phải có dòng `` `include "mips_defines.vh" `` ở đầu mỗi file .v
- Sử dụng dấu `` ` `` trước các macro (Ví dụ: `` `ALU_ADD `` )
- Không hardcode các giá trị Opcode, Funct, hay kích thước bit## 3. LOGIC THỜI GIAN & ĐẶC THÙ PIPELINE

### Tập thanh ghi (regfile.v)
- **GHI (Write):** Thực hiện ở nửa chu kỳ đầu (cạnh xuống - negedge clk)
- **ĐỌC (Read):** Thực hiện logic tổ hợp (bất đồng bộ) để hỗ trợ Internal Forwarding

### Bộ nhớ dữ liệu (data_memory.v)
- **GHI:** Thực hiện ở cạnh lên (posedge clk)
- **ĐỌC:** Thực hiện logic tổ hợp (đọc ra ngay khi có địa chỉ)

### Thanh ghi Pipeline
- Phải có chân stall (đóng băng) và flush (xóa lệnh)## 4. GIAO THỨC GIAO TIẾP (INTERFACE CONTRACT)

Các thành viên phải copy chính xác tên cổng dưới đây:

### 4.1. Nhóm Datapath (Hiếu phụ trách)

#### 1. Khối ALU (alu.v)

```verilog
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_control,
    output reg  [31:0] result,
    output wire        zero
);
```

#### 2. Khối Register File (regfile.v)

```verilog
module regfile (
    input  wire        clk,
    input  wire        reset,
    input  wire        reg_write,
    input  wire [4:0]  read_reg1,     // rs
    input  wire [4:0]  read_reg2,     // rt
    input  wire [4:0]  write_reg,     // rd hoặc rt từ tầng WB
    input  wire [31:0] write_data,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2
);
```

#### 3. Khối Sign Extend (sign_extend.v)

```verilog
module sign_extend (
    input  wire [15:0] imm_in,
    output wire [31:0] imm_ext
);
```

### 4.2. Nhóm Control & Memory (An phụ trách)

#### 1. Khối Main Control (control_unit.v)

```verilog
module control_unit (
    input  wire [5:0] opcode,
    output reg        reg_dst,
    output reg        branch,
    output reg        mem_read,
    output reg        mem_to_reg,
    output reg  [1:0] alu_op,
    output reg        mem_write,
    output reg        alu_src,
    output reg        reg_write,
    output reg        jump
);
```

#### 2. Khối ALU Control (alu_control.v)

```verilog
module alu_control (
    input  wire [1:0] alu_op,
    input  wire [5:0] funct,
    output reg  [3:0] alu_ctrl
);
```

#### 3. Bộ nhớ Lệnh (inst_memory.v)

Yêu cầu: Nạp chương trình Fibonacci từ `asm/fibonacci.hex`.

```verilog
module inst_memory (
    input  wire [31:0] address,
    output wire [31:0] instruction
);
// Sử dụng $readmemh("asm/fibonacci.hex", memory)
```

#### 4. Bộ nhớ Dữ liệu (data_memory.v)

```verilog
module data_memory (
    input  wire        clk,
    input  wire        mem_write,
    input  wire        mem_read,
    input  wire [31:0] address,
    input  wire [31:0] write_data,
    output wire [31:0] read_data
);
```
## 5. KIỂM THỬ VÀ TÍCH HỢP (TỰ & DUNG)

**Tự (System Architect):** Xây dựng `hazard_unit.v` để điều khiển các tín hiệu stall và flush cho các tầng pipeline. Đảm bảo nối dây đúng theo Interface Contract trên.

**Dung (QA/Test):** Sử dụng mã nguồn Fibonacci chính thức. Trong Testbench, bắt buộc thêm khối sau để xuất dạng sóng:

```verilog
initial begin
    $dumpfile("waves/mips_sim.vcd");
    $dumpvars(0, mips_tb);
end
```

---

**GHI CHÚ:** Mọi thay đổi về Interface phải được sự đồng ý của Nhóm trưởng (Tự) và cập nhật vào văn bản này trước khi thực hiện code.