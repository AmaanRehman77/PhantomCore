module instr_queue 
import mem_types_pkg::*;
import frontend_pkg::*;
#(
	parameter IQUEUE_INDEX_WIDTH = 2
)
(
	input logic clk,
	input logic rst,

	input logic [31:0] pc_wdata,
	// input logic flush,

	input logic dequeue,
	output logic empty,
    output logic full,
	output fetch_t deq_instruction
);

localparam NUM_IQUEUE_ENTRIES =  2**IQUEUE_INDEX_WIDTH;


// QUEUE DECLARATIONS
logic [IQUEUE_INDEX_WIDTH:0] head, tail, head_next, tail_next;
fetch_t entries [NUM_IQUEUE_ENTRIES];
fetch_t entries_next [NUM_IQUEUE_ENTRIES];

// QUEUE
assign deq_instruction = entries[head[IQUEUE_INDEX_WIDTH-1:0]];
assign full = (
	(head[IQUEUE_INDEX_WIDTH-1:0] == tail[IQUEUE_INDEX_WIDTH-1:0]) && 
	(head[IQUEUE_INDEX_WIDTH] != tail[IQUEUE_INDEX_WIDTH]) &&
	(!dequeue)
);
assign empty = (
	(head[IQUEUE_INDEX_WIDTH-1:0] == tail[IQUEUE_INDEX_WIDTH-1:0]) && 
	(head[IQUEUE_INDEX_WIDTH] == tail[IQUEUE_INDEX_WIDTH])
);

always_ff @ (posedge clk) begin

	if (rst) begin
		head <= '0;
		tail <= '0;
	end

	else begin
		for (int unsigned i=0 ; i < NUM_IQUEUE_ENTRIES; ++i) begin
			entries[i] <= entries_next[i];
		end
		head <= head_next;
		tail <= tail_next;
	end

end

always_comb begin

	for (int unsigned i=0 ; i < NUM_IQUEUE_ENTRIES; ++i) begin
		entries_next[i] = entries[i];
	end
	head_next = head;
	tail_next = tail;

	if (dequeue && !empty) begin
		head_next = head + (IQUEUE_INDEX_WIDTH)'('b1);
	end

	if (i_resp.resp && !full) begin
		entries_next[tail[IQUEUE_INDEX_WIDTH-1:0]] = '{
			instruction: i_resp.rdata,
			pc: pc
		};
		tail_next = tail + (IQUEUE_INDEX_WIDTH)'('b1);
	end

end

endmodule