// file: defines.v
// author: @shalan

`default_nettype none

`define		sync_begin(X)	always @ (posedge clk or posedge rst) if(rst)	X <= 0; else begin
`define		sync_end		end

`define     IR_rs1          19:15
`define     IR_rs2          24:20
`define     IR_rd           11:7
`define     IR_opcode       6:2
`define     IR_funct3       14:12
`define     IR_funct7       31:25
`define     IR_shamt        24:20
`define     IR_csr          31:20

`define     OPCODE_Branch   5'b11_000
`define     OPCODE_Load     5'b00_000
`define     OPCODE_Store    5'b01_000
`define     OPCODE_JALR     5'b11_001
`define     OPCODE_JAL      5'b11_011
`define     OPCODE_Arith_I  5'b00_100
`define     OPCODE_Arith_R  5'b01_100
`define     OPCODE_AUIPC    5'b00_101
`define     OPCODE_LUI      5'b01_101
`define     OPCODE_SYSTEM   5'b11_100 
`define     OPCODE_Custom   5'b10_001

`define     F3_ADD          3'b000
`define     F3_SLL          3'b001
`define     F3_SLT          3'b010
`define     F3_SLTU         3'b011
`define     F3_XOR          3'b100
`define     F3_SRL          3'b101
`define     F3_OR           3'b110
`define     F3_AND          3'b111

`define     BR_BEQ          3'b000
`define     BR_BNE          3'b001
`define     BR_BLT          3'b100
`define     BR_BGE          3'b101
`define     BR_BLTU         3'b110
`define     BR_BGEU         3'b111

`define     OPCODE          IR[`IR_opcode]

`define     ALU_ADD         4'b00_00
`define     ALU_SUB         4'b00_01
`define     ALU_PASS        4'b00_11
`define     ALU_OR          4'b01_00
`define     ALU_AND         4'b01_01
`define     ALU_XOR         4'b01_11
`define     ALU_SRL         4'b10_00
`define     ALU_SRA         4'b10_10
`define     ALU_SLL         4'b10_01
`define     ALU_SLT         4'b11_01
`define     ALU_SLTU        4'b11_11

`define     SYS_EC_EB       3'b000
`define     SYS_CSRRW       3'b001
`define     SYS_CSRRS       3'b010
`define     SYS_CSRRC       3'b011
`define     SYS_CSRRWI      3'b101
`define     SYS_CSRRSI      3'b110
`define     SYS_CSRRCI      3'b111

/*
	V0: 
		+ Pipelined implemenattion of RV32I 
		+ 100MHz target with < 4000 Gates
		+ Dual ported memory for the RF
		+ Von Neumann memory architecture
*/

module mux32_2x1(input [31:0] a, b, input s, output[31:0] y);
	assign y = s ? b : a;
endmodule
module PC4( input [31:0] pc, output [31:0] pc4);
	assign pc4 = pc + 32'd4;
endmodule

module PCI( input [31:0] pc, i, output [31:0] pci);
        assign pci = pc + i;
endmodule
/*
module DEC (
	input   wire [31:0] IR,
    output	reg  [3:0]	ALU_fn,
    output  wire        jalr,
    output  wire        jal,
    output  wire        auipc
);

	wire [4:0]  opcode      =   `OPCODE;
    wire [2:0]  func3       =   IR[`IR_funct3];
    wire [6:0]  func7       =   IR[`IR_funct7];
    
    wire        I           =   (opcode == `OPCODE_Arith_I);
	wire        R           =   (opcode == `OPCODE_Arith_R);
	wire        IorR        =   I | R;
	wire        instr_logic = ((IorR==1'b1) && ((func3==`F3_XOR) || (func3==`F3_AND) || (func3==`F3_OR)));
	wire        instr_shift = ((IorR==1'b1) && ((func3==`F3_SLL) || (func3==`F3_SRL) ));
	wire        instr_slt   = ((IorR==1'b1) && (func3==`F3_SLT));
	wire        instr_sltu  = ((IorR==1'b1) && (func3==`F3_SLTU));
	wire        instr_store = (opcode == `OPCODE_Store);
	wire        instr_load  = (opcode == `OPCODE_Load);
	wire        instr_add   = R & (func3 == `F3_ADD) & (~func7[5]);
	wire        instr_sub   = R & (func3 == `F3_ADD) & (func7[5]);
	wire        instr_addi  = I & (func3 == `F3_ADD);
	wire        instr_lui   = (opcode == `OPCODE_LUI);
	wire        instr_auipc = (opcode == `OPCODE_AUIPC);
	wire        instr_branch = (opcode == `OPCODE_Branch);
	wire        instr_jalr  = (IR[`IR_opcode] == `OPCODE_JALR);
	wire        instr_jal   = (IR[`IR_opcode] == `OPCODE_JAL);
	wire        instr_sll   = ((IorR==1'b1) && (func3 == `F3_SLL) && (func7 == 7'b0)); 
	wire        instr_srl   = ((IorR==1'b1) && (func3 == `F3_SRL) && (func7 == 7'b0));
	wire        instr_sra   = ((IorR==1'b1) && (func3 == `F3_SRL) && (func7 != 7'b0));
	wire        instr_and   = ((IorR==1'b1) && (func3 == `F3_AND));
	wire        instr_or    = ((IorR==1'b1) && (func3 == `F3_OR));
	wire        instr_xor   = ((IorR==1'b1) && (func3 == `F3_XOR));


	// change
	assign 	PC_load = 1;
	assign	PC_sel 	= 0;


	always @ * begin
        case (1'b1)		
            instr_load  :   ALU_fn = `ALU_ADD;
            instr_addi  :   ALU_fn = `ALU_ADD;
            instr_store :   ALU_fn = `ALU_ADD;
            instr_add   :   ALU_fn = `ALU_ADD; 
            instr_jalr  :   ALU_fn = `ALU_ADD;
            
            instr_lui   :   ALU_fn = `ALU_PASS;
            
            instr_sll   :   ALU_fn = `ALU_SLL;
            instr_srl   :   ALU_fn = `ALU_SRL;
            instr_sra   :   ALU_fn = `ALU_SRA;
            
            instr_slt   :   ALU_fn = `ALU_SLT;
            instr_sltu  :   ALU_fn = `ALU_SLTU;
            
            instr_and   :   ALU_fn = `ALU_AND;
            instr_or    :   ALU_fn = `ALU_OR;
            instr_xor   :   ALU_fn = `ALU_XOR;
            
            default     :   ALU_fn = `ALU_SUB;
        endcase
    end

endmodule
*/
/*
	PC Unit
	Port:
		Sel:	00		PC + 4
				10		PC + 2
				01		TA
				11		PC + Imm
		load	write to PC
	Size:
		448	gates -- scpt_2 

*/

module PCUnit (
	input	wire				clk,
	input	wire				rst,
	input	wire 	[31:0]		TA,
	input	wire 	[31:0]		Imm,
	output	reg		[31:0]		PC,
	output	wire	[31:0]		ftPC,
	output	wire	[31:0]		iPC,
	input	wire				load,
	input	wire	[1:0]		sel			
);

	wire [31:0]	nPC;
	assign	nPC		=	sel[1] ? iPC : TA;
	assign 	ftPC	= 	PC + (sel[1] ? 32'h2 : 32'h4);
	assign 	iPC		=	PC + Imm;

	always @ (posedge clk or posedge rst)
	if(rst)	
		PC <= 32'b0;
	else if(load)
		case (sel[0]) // synopsys full_case parallel_case
			1'b0	:	PC <= ftPC;
			2'b1	:	PC <= nPC; 
		endcase
endmodule


/*
	ALU for the 
    00_00: Add
    00_01: sub
    00_11: passthrough
    01_00: or
    01_01: and
    01_11: xor
    10_00: srl
    10_10: sra
    10_01: srl
    11_01: slt
    11_11: sltu

    Size:	1024 Gates
*/

module ALU(
	input   wire [31:0] a, b,
	input   wire [4:0]  shamt,
	output  reg  [31:0] r,
	output  wire        cf, zf, vf, sf,
	input   wire [3:0]  alufn
);

    wire [31:0] add, sub, op_b;
    wire cfa, cfs;
    
    assign op_b = (~b);
    
    assign {cf, add} = alufn[0] ? (a + op_b + 1'b1) : (a + b);
    
    assign zf = (add == 0);
    assign sf = add[31];
    assign vf = (a[31] ^ (op_b[31]) ^ add[31] ^ cf);
    
    wire[31:0] sh;
    shifter shifter0(.a(a), .shamt(shamt), .type(alufn[1:0]),  .r(sh));
    
    always @ * begin
        r = 0;
        
        case (alufn)	
            // arithmetic
            4'b00_00 : r = add;
            4'b00_01 : r = add;
            4'b00_11 : r = b;
            // logic
            4'b01_00:  r = a | b;
            4'b01_01:  r = a & b;
            4'b01_11:  r = a ^ b;
            // shift
            4'b10_00:  r=sh;
            4'b10_01:  r=sh;
            4'b10_10:  r=sh;
            // slt & sltu
            4'b11_01:  r = {31'b0,(sf != vf)}; 
            4'b11_11:  r = {31'b0,(~cf)};            	
        endcase
    end
endmodule


module mirror (input [31:0] in, output reg [31:0] out);
    integer i;
    always @ *
        for(i=0; i<32; i=i+1)
            out[i] = in[31-i];
endmodule

module shr(input [31:0] a, output [31:0] r, input [4:0] shamt, input ar);
    
    wire [31:0] r1, r2, r3, r4;
    
    wire fill = ar ? a[31] : 1'b0;
    assign r1 = shamt[0] ? {fill, a[31:1]} : a;
    assign r2 = shamt[1] ? {fill, fill, r1[31:2]} : r1;
    assign r3 = shamt[2] ? {{4{fill}}, r2[31:4]} : r2;
    assign r4 = shamt[3] ? {{8{fill}}, r3[31:8]} : r3;
    assign r = shamt[4] ? {{16{fill}}, r4[31:16]} : r4;
    
endmodule 

// type[0] sll or srl
// type[1] sra
// 00 : srl
// 10 : sra
// 01 : sll
module shifter(input[31:0] a, input [4:0] shamt, input[1:0] type,  output [31:0] r);
    wire [31 : 0] ma, my, y, x, sy;
    
    mirror m1(.in(a), .out(ma));
    mirror m2(.in(y), .out(my));
    
    assign x = type[0] ? ma : a;
    shr sh0(.a(x), .r(y), .shamt(shamt), .ar(type[1]));
    
    assign r = type[0] ? my : y;
    
endmodule


/*

	Immediate Generator

	Size: 63 gates

*/

module IMMGen (
    input  wire [31:0]  IR,
    output reg  [31:0]  Imm
);

always @(*) begin
	case (`OPCODE)
		`OPCODE_Arith_I   : 	Imm = { {21{IR[31]}}, IR[30:25], IR[24:21], IR[20] };
		`OPCODE_Store     :     Imm = { {21{IR[31]}}, IR[30:25], IR[11:8], IR[7] };
		`OPCODE_LUI       :     Imm = { IR[31], IR[30:20], IR[19:12], 12'b0 };
		`OPCODE_AUIPC     :     Imm = { IR[31], IR[30:20], IR[19:12], 12'b0 };
		`OPCODE_JAL       : 	Imm = { {12{IR[31]}}, IR[19:12], IR[20], IR[30:25], IR[24:21], 1'b0 };
		`OPCODE_JALR      : 	Imm = { {21{IR[31]}}, IR[30:25], IR[24:21], IR[20] };
		`OPCODE_Branch    : 	Imm = { {20{IR[31]}}, IR[7], IR[30:25], IR[11:8], 1'b0};
		default           : 	Imm = { {21{IR[31]}}, IR[30:25], IR[24:21], IR[20] }; // IMM_I
	endcase 
end

endmodule


module CPU (
	input   wire          clk, 
	input   wire          rst, 
	output  wire	[31:0] 	mAddr, 
	output  wire	[31:0] 	mDo, 
	input   wire	[31:0] 	mDi, 
	output  wire    [1:0]   mSize,
	output  wire		    mWr,
	output  wire	[4:0] 	rfRS1, 
	output  wire	[4:0] 	rfRS2, 
	output  wire	[4:0] 	rfRD, 
	input   wire	[31:0] 	rfD1, 
	input   wire	[31:0] 	rfD2,
	output  wire	[31:0]	rfWD,
	output  wire			rfWr,
	input   wire            int,
	output  wire    [2:0]   int_num,
	input   wire            nmi
);

// Registers
reg	[31:0]	IR;				
reg	[31:0]	I, R1, R2, iPC, ftPC;	// S 0-1 Regs
reg	[31:0] 	MD, R, RA;				// S 1-2 Regs
reg 		cycle;

// S1 wires
wire [31:0] w_PC, w_ftPC, w_iPC, w_Imm, w_TA;
wire 		c_PC_load;

// S2 wires
wire [31:0]	w_ALU_A, w_ALU_B, w_ALU_R, w_MEM_Do, w_RA;
wire 		w_ALU_cf, w_ALU_zf, w_ALU_sf, w_ALU_vf;
wire [3:0]	c_ALU_fn;
wire 		c_ALU_A_sel, c_ALU_B_sel, c_Mem_Do_sel, c_RA_sel, c_TA_sel, c_ALU_A_fwd, c_ALU_B_fwd;
wire [1:0]	c_PC_sel;

// S3 wires
wire [31:0]	w_WB_mux;
wire [1:0] c_WB_sel;

always @(posedge clk or posedge rst)
	if(rst)
		cycle <= 0;
	else 
		cycle <= ~ cycle;

// Stage 1 : Fetch, Decode % Regs read

PCUnit pcu (
	.clk(clk),
	.rst(rst),
	.TA(w_TA),
	.Imm(w_Imm),
	.PC(w_PC),
	.ftPC(w_ftPC),
	.iPC(w_iPC),
	.load(c_PC_load),
	.sel(c_PC_sel)			
);

IMMGen igen(
    .IR(IR),
    .Imm(w_Imm)
);

DEC dec (
	.IR(IR),
    .PC_load(c_PC_load),
	.PC_sel(c_PC_sel),
	.ALU_fn(),
	.ALU_A_sel(), 
	.ALU_B_sel(), 
	.Mem_Do_sel(), 
	.RA_sel(), 
	.TA_sel(), 
	.ALU_A_fwd(), 
	.ALU_B_fwd(),
	.WB_sel()
);

always @(posedge clk or posedge rst)
	if(rst) IR <= 0;
	else if(cycle == 1'b0) IR <= mDi;

always @(posedge clk or posedge rst)
	if(rst) R1 <= 0;
	else if(cycle == 1'b1) R1 <= rfD1;

always @(posedge clk or posedge rst)
	if(rst) R2 <= 0;
	else if(cycle == 1'b1) R2 <= rfD1;

always @(posedge clk or posedge rst)
	if(rst) I <= 0;
	else if(cycle) I <= w_Imm;

always @(posedge clk or posedge rst)
	if(rst) iPC <= 0;
	else if(cycle) iPC <= w_iPC;

always @(posedge clk or posedge rst)
	if(rst) ftPC <= 0;
	else if(cycle) ftPC <= w_ftPC;
	
// Stage 2 : ALU & Mem
ALU alu(
	.a(w_ALU_A), 
	.b(w_ALU_B),
	.shamt(),
	.r(w_ALU_R),
	.cf(w_ALU_cf), .zf(w_ALU_zf), .vf(w_ALU_vf), .sf(w_ALU_sf),
	.alufn(c_ALU_fn)
);

assign w_ALU_A	=	(c_ALU_A_fwd) ? w_WB_mux : R1;
assign w_ALU_B	=	(c_ALU_B_fwd) ? w_WB_mux : (c_ALU_B_sel) ? R2 : I;

always @(posedge clk or posedge rst)
	if(rst) R <= 0;
	else if(cycle) R <= w_ALU_R;

always @(posedge clk or posedge rst)
	if(rst) RA <= 0;
	else if(cycle) RA <= w_RA;

always @(posedge clk or posedge rst)
	if(rst) MD <= 0;
	else if(cycle) MD <= mDi;

// Stages 3
assign	w_WB_mux =	(c_WB_sel[0]) ? R : 
					(c_WB_sel[1]) ? MD : RA;


endmodule

