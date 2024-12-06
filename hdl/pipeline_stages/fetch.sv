module fetch 
import mem_types_pkg::*;
import frontend_pkg::*;
#(
	parameter IQUEUE_INDEX_WIDTH = 2
)
(
	input logic clk,
	input logic rst,

	output mem_rqst_t i_rqst,
	input mem_resp_t i_resp,

	input logic [31:0] pc_wdata,                        // FOR FLUSHES

);

logic [31:0] pc, pc_wdata;

// QUEUE Variables
logic dequeue, empty, full;
fetch_t deq_instruction

// ############## FLUSH ###############
assign flush = 1'b0;
assign pc_wdata = '0;

// IMEM REQUEST
assign i_rqst.address = pc;
assign i_rqst.rd_en = 1'b1;
assign i_rqst.wr_en = 1'b0;
assign i_rqst.mask = '0;
assign i_rqst.wdata = 'x;

always_ff @ (posedge clk) begin : setting_pc_reg
	if (rst) begin
		pc <= 32'h1eceb_0000;
	end
	else begin
		if (flush) begin
			pc <= pc_wdata;
		end
		else if (i_resp.resp && !full) begin
			pc <= pc + 32'h4;
		end
	end
end

instr_queue instr_queue (.*);


endmodule