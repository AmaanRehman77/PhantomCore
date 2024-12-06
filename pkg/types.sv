apackage params;
	localparam L1_D_INDEX_WIDTH = 4;
	localparam L1_D_WAY_WIDTH = 2;
	localparam L1_D_TWO_CYCLE = 0;

	localparam L1_I_INDEX_WIDTH = 4;
	localparam L1_I_WAY_WIDTH = 2;
	localparam L1_I_TWO_CYCLE = 0;

	localparam ROB_INDEX_WIDTH = 4;
	localparam IQUEUE_INDEX_WIDTH = 3;
	localparam PHYS_REGS_INDEX_WIDTH = 6;
	localparam NUM_RS = 8;
	localparam NUM_MEM_RS = 4;
	localparam NUM_STORE_BUFFER_ENTRIES = 2;
	localparam NUM_CONTROL_BUFFER_ENTRIES = 2;
	localparam COMMIT_WIDTH = 1;

	localparam NUM_ALU = 1;
	localparam NUM_CMP = 1;
	localparam NUM_MUL = 1;

	localparam NUM_CDB = 1;

	localparam NUM_FREE_LIST_ENTRIES = (2**PHYS_REGS_INDEX_WIDTH) - 32;
endpackage

package rvfi_pkg;

	typedef struct packed {
	// RVFI Control
		logic valid;
		logic [63:0] order;
	// Instruction and trap
		logic [31:0] inst;
		logic trap;

	// Regfile
		logic [4:0] rs1_addr;
		logic [4:0] rs2_addr;
		logic [31:0] rs1_rdata;
		logic [31:0] rs2_rdata;
		logic load_regfile;
		logic [4:0] rd_addr;
		logic [31:0] rd_wdata;

	// PC
		logic [31:0] pc_rdata;
		logic [31:0] pc_wdata;

	// Memory
		logic [31:0] mem_addr;
		logic [3:0] mem_rmask;
		logic [3:0] mem_wmask;
		logic [31:0] mem_rdata;
		logic [31:0] mem_wdata;
	} rvfi_t;

endpackage : rvfi_pkg

package mem_types_pkg;

typedef struct packed {
	logic [31:0] address;
	logic rd_en;
	logic wr_en;
	logic [3:0] mask;
	logic [31:0] wdata;
} mem_rqst_t;

typedef struct packed {
	logic [31:0] rdata;
	logic resp;
} mem_resp_t;

typedef struct packed {
	logic [31:0] address;
	logic rd_en;
	logic wr_en;
	logic [31:0] mask;
	logic [255:0] wdata;
} cacheline_rqst_t;

typedef struct packed {
	logic [255:0] rdata;
	logic resp;
} cacheline_resp_t;

endpackage

package frontend_pkg;
	import rvfi_pkg::*;
	import params::*;
	import mem_types_pkg::*;

	typedef enum logic [2:0] {
		dispatch_op_type_alu,
		dispatch_op_type_cmp,
		dispatch_op_type_ld,
		dispatch_op_type_st,
		dispatch_op_type_mul,
		dispatch_op_type_div,
		dispatch_op_type_immexec,
		dispatch_op_type_UNUSED
	} dispatch_op_type_t;

	typedef enum logic [1:0] {
		rob_op_type_rd,
		rob_op_type_st,
		rob_op_type_control,
		rob_op_type_jalr
	} rob_op_type_t;

	typedef struct {
		logic [31:0] instruction;
		logic [31:0] pc;
	} fetch_t;

	typedef struct {
		logic valid;
		dispatch_op_type_t dispatch_op_type;
		rob_op_type_t rob_op_type;
		logic [2:0] funct3;
		logic modifier;
		logic [4:0] rs1;
		logic [4:0] rs2;
		logic [31:0] imm;
		logic [31:0] pc_when_needed;
		logic [4:0] rd;
		rvfi_t rvfi;
	} muop_t;

	typedef struct {
		logic valid;
		logic [PHYS_REGS_INDEX_WIDTH-1:0] pd;
	} rat_t;

	typedef struct {
		logic valid;
		dispatch_op_type_t op_type; // used to select function unit
		logic [2:0] funct3;
		logic modifier; // use_imm, taken/not_taken
		rat_t ps1;
		rat_t ps2;
		logic [31:0] imm;
		logic [PHYS_REGS_INDEX_WIDTH-1:0] pd;
		logic [4:0] rd;
		logic [ROB_INDEX_WIDTH-1:0] rob_index;
		rvfi_t rvfi;
	} rs_t;

	typedef struct {
		logic valid;
		logic [2:0] funct3;
		logic [31:0] src1;
		logic [31:0] src2;
		logic [PHYS_REGS_INDEX_WIDTH-1:0] pd;
		logic [4:0] rd;
		logic [ROB_INDEX_WIDTH-1:0] rob_index;
		rvfi_t rvfi;
	} alu_stage1_t;

	typedef struct {
		logic valid;
		logic [2:0] funct3;
		logic [31:0] base;
		logic [31:0] offset;
		logic [31:0] wdata;
		logic [PHYS_REGS_INDEX_WIDTH-1:0] pd;
		logic [4:0] rd;
		logic [ROB_INDEX_WIDTH-1:0] rob_index;
		rvfi_t rvfi;
	} mem_stage1_t;

	typedef struct {
		logic valid;
		logic [2:0] funct3;
		logic [31:0] address;
		logic [31:0] wdata;
		logic [PHYS_REGS_INDEX_WIDTH-1:0] pd;
		logic [4:0] rd;
		logic [ROB_INDEX_WIDTH-1:0] rob_index;
		rvfi_t rvfi;
	} mem_stage2_t;

	typedef struct {
		logic valid;
		logic [31:0] address;
		logic [31:0] wdata;
		logic [3:0] mask;
	} store_buffer_t;

	typedef struct {
		logic valid;
		logic [ROB_INDEX_WIDTH-1:0] rob_index;
		logic [31:0] address;
		logic [31:0] pc; // used for branch predictor
		logic take;
		logic prediction;
		logic is_jalr;
	} control_buffer_t;
	

	typedef struct {
		logic valid;
		rob_op_type_t op_type;
		logic [4:0] rd;
		logic [PHYS_REGS_INDEX_WIDTH-1:0] pd;
		rvfi_t rvfi;
	} rob_t;

	typedef struct {
		logic valid;
		logic [4:0] rd;
		logic [PHYS_REGS_INDEX_WIDTH-1:0] pd;
		logic [31:0] pd_wdata;
		logic [ROB_INDEX_WIDTH-1:0] rob_index;
		dispatch_op_type_t rvfi_dispatch_op_type;
		rvfi_t rvfi;
	} cdb_t;

	typedef struct {
		logic rename;
		logic [4:0] rd;
		logic [PHYS_REGS_INDEX_WIDTH-1:0] pd;
		logic [4:0] rs1;
		logic [4:0] rs2;
	} rename_rqst_t;

	typedef struct {
		rat_t ps1;
		rat_t ps2;
	} rename_resp_t;
endpackage

package funct3_pkg;

typedef logic [6:0] funct7_t;
typedef logic [2:0] funct3_t;

typedef enum funct3_t {
	arith_add  = 3'b000, //check bit30 for sub if op_reg opcode
	arith_sll  = 3'b001,
	arith_slt  = 3'b010,
	arith_sltu = 3'b011,
	arith_axor = 3'b100,
	arith_sr   = 3'b101, //check bit30 for logical/arithmetic
	arith_aor  = 3'b110,
	arith_aand = 3'b111
} arith_funct3_t;

typedef enum funct3_t {
	cmp_beq  = 3'b000,
	cmp_bne  = 3'b001,
	cmp_force_jmp,
	cmp_blt  = 3'b100,
	cmp_bge  = 3'b101,
	cmp_bltu = 3'b110,
	cmp_bgeu = 3'b111
} cmp_op_t;

typedef enum funct3_t {
	alu_add = 3'b000,
	alu_sll = 3'b001,
	alu_sra = 3'b010,
	alu_sub = 3'b011,
	alu_xor = 3'b100,
	alu_srl = 3'b101,
	alu_or  = 3'b110,
	alu_and = 3'b111
} alu_op_t;

typedef enum logic [1:0] {
    mul    = 2'b00,
    mulh   = 2'b01,
    mulhsu = 2'b10,
    mulhu  = 2'b11
} mul_funct3_t;

typedef enum logic [1:0] {
    div  = 2'b00,
    divu = 2'b01,
    rem  = 2'b10,
    remu = 2'b11
} div_funct3_t;

typedef enum funct3_t {
	mem_lb,
	mem_lh,
	mem_lw,
	mem_lbu,
	mem_lhu,
	mem_sb,
	mem_sh,
	mem_sw
} mem_funct3_t;

typedef enum logic [2:0] {
	load_b  = 3'b000,
	load_h  = 3'b001,
	load_w  = 3'b010,
	load_bu = 3'b100,
	load_hu = 3'b101
} load_funct3_t;

typedef enum logic [2:0] {
	store_b = 3'b000,
	store_h = 3'b001,
	store_w = 3'b010
} store_funct3_t;

endpackage


package rv32i_opcode_pkg;

typedef enum logic [6:0] {
	op_lui   = 7'b0110111, //load upper immediate (U type)
	op_auipc = 7'b0010111, //add upper immediate PC (U type)
	op_jal   = 7'b1101111, //jump and link (J type)
	op_jalr  = 7'b1100111, //jump and link register (I type)
	op_br    = 7'b1100011, //branch (B type)
	op_load  = 7'b0000011, //load (I type)
	op_store = 7'b0100011, //store (S type)
	op_imm   = 7'b0010011, //arith ops with register/immediate operands (I type)
	op_reg   = 7'b0110011, //arith ops with register operands (R type)
	op_csr   = 7'b1110011  //control and status register (I type)
} rv32i_opcode_t;
endpackage

package rv32i_types;
import params::*;
typedef logic [31:0] rv32i_word;

endpackage