module i_cache
import rv32i_types::*;
#(
    parameter               NUM_SETS     = 16,
    parameter               NUM_WAYS     = 4
) (
    input   logic           clk,
    input   logic           rst,

    // cpu side signals, ufp -> upward facing port
    input   logic   [31:0]  ufp_addr,
    input   logic   [3:0]   ufp_rmask,
    input   logic   [3:0]   ufp_wmask,
    output  logic   [(32*SS_FETCH)-1:0]  ufp_rdata,
    input   logic   [31:0]  ufp_wdata,
    output  logic           ufp_resp,

    // memory side signals, dfp -> downward facing port
    output  logic   [31:0]  dfp_addr,
    output  logic           dfp_read,
    output  logic           dfp_write,
    input   logic   [255:0] dfp_rdata,
    output  logic   [255:0] dfp_wdata,
    input   logic           dfp_resp
);

    localparam SET_BITS = $clog2(NUM_SETS); //local_log2(NUM_SETS);
    localparam TAG_BITS = 32 - SET_BITS - 5;
    localparam WAY_BITS = $clog2(NUM_WAYS); //local_log2(NUM_WAYS);
    // function int local_log2 (input int input_num);
    //     const int count = -1;
    //     for (int unsigned tmp = input_num; tmp > 0; tmp = tmp >> 1, count++) begin
    //         // count++;
    //     end
    //     // count -= 1;
    //     return count;
    // endfunction
    // int oausbcasbc = local_log2(NUM_SETS);
    // initial begin
    // //     for (int unsigned tmp = NUM_SETS; tmp > 0; tmp = tmp >> 1) begin
    // //         SET_BITS++;
    // //     end
    // //     SET_BITS -= 1;
    // //     TAG_BITS = 32 - SET_BITS - 5;

    // end


    logic   [255:0]  data_array_din     [NUM_WAYS];
    logic   [255:0]  data_array_dout    [NUM_WAYS];
    logic   data_array_web              [NUM_WAYS];
    logic   [31:0]   data_array_wmask   [NUM_WAYS];

    logic   [TAG_BITS:0]   tag_array_din      [NUM_WAYS];
    logic   [TAG_BITS:0]   tag_array_dout     [NUM_WAYS];
    logic   tag_array_web               [NUM_WAYS];

    logic   valid_array_din             [NUM_WAYS];
    logic   valid_array_dout            [NUM_WAYS];
    logic   valid_array_web             [NUM_WAYS];

    // logic   dirty_array_din             [NUM_WAYS];
    // logic   dirty_array_dout            [NUM_WAYS];
    // logic   dirty_array_web             [NUM_WAYS];

    logic   [NUM_WAYS-2:0]   plru_array_din;
    logic   [NUM_WAYS-2:0]   plru_array_din_array [NUM_WAYS];

    logic   [NUM_WAYS-2:0]   plru_array_dout;
    logic   plru_array_web;

    logic   hit;
    logic   [WAY_BITS - 1:0]   hit_index, shadow_to_cache_idx, to_cache_idx, plru_direct_logic_next;

    enum logic [2:0] {idle_state, compare_state, wb_state, alloc_state, rw_dependency_state} curr_state, next_state;
    
    logic   [31:0]  s_ufp_addr;
    logic   [3:0]   s_ufp_rmask;
    logic   [3:0]   s_ufp_wmask;
    logic   [31:0]  s_ufp_wdata;


    logic [63:0] i_cache_misses;

// is this idle state?
    generate for (genvar i = 0; i < NUM_WAYS; i++) begin : arrays
        mp_cache_data_array #(.ADDR_WIDTH(SET_BITS)) data_array (
            .clk0       (clk),
            .csb0       ('0),
            .web0       (~data_array_web[i]),
            .wmask0     (data_array_wmask[i]),                 // writes byte by byte..
            .addr0      (s_ufp_wmask != '0 ? s_ufp_addr[5 + SET_BITS - 1 : 5] : ufp_addr[5 + SET_BITS - 1 : 5]),
            .din0       (data_array_din[i]),
            .dout0      (data_array_dout[i])
        );
        mp_cache_tag_array #(.DATA_WIDTH(TAG_BITS+1), .ADDR_WIDTH(SET_BITS)) tag_array (
            .clk0       (clk),
            .csb0       ('0),
            .web0       (~tag_array_web[i]),
            .addr0      (s_ufp_wmask != '0 ? s_ufp_addr[5 + SET_BITS - 1 : 5] : ufp_addr[5 + SET_BITS - 1 : 5]),
            .din0       (tag_array_din[i]),
            .dout0      (tag_array_dout[i])
        );
        ff_array #(.S_INDEX(SET_BITS), .WIDTH(1)) valid_array (
            .clk0       (clk),
            .rst0       (rst),
            .csb0       ('0),
            .web0       (~valid_array_web[i]),
            .addr0      (s_ufp_wmask != '0 ? s_ufp_addr[5 + SET_BITS - 1 : 5] : ufp_addr[5 + SET_BITS - 1 : 5]),
            .din0       (valid_array_din[i]),
            .dout0      (valid_array_dout[i])
        );
        // ff_array #(.S_INDEX(SET_BITS), .WIDTH(1)) dirty_array (
        //     .clk0       (clk),
        //     .rst0       (rst),
        //     .csb0       ('0),
        //     .web0       (~dirty_array_web[i]),
        //     .addr0      (s_ufp_wmask != '0 ? s_ufp_addr[5 + SET_BITS - 1 : 5] : ufp_addr[5 + SET_BITS - 1 : 5]),
        //     .din0       (dirty_array_din[i]),
        //     .dout0      (dirty_array_dout[i])
        // );
        plru_logic #(.PLRU_SIZE(NUM_WAYS-1), .WAY_BITS(WAY_BITS)) plru_logic_creator (
            .curr_idx(i[WAY_BITS - 1 : 0]),
            .plru_curr(plru_array_dout),
            .plru_next(plru_array_din_array[i])
        );
    end endgenerate

    ff_array #(.S_INDEX(SET_BITS), .WIDTH(NUM_WAYS-1)) plru_array (
        .clk0       (clk),
        .rst0       (rst),
        .csb0       ('0),
        .web0       (~plru_array_web),
        .addr0      (s_ufp_addr[5 + SET_BITS - 1 : 5]),
        .din0       (plru_array_din),
        .dout0      (plru_array_dout)
    );

    plru_to_replace_idx #(.PLRU_SIZE(NUM_WAYS-1), .WAY_BITS(WAY_BITS)) plru_to_replace_idx (
    .plru_curr(plru_array_dout),
    .to_cache_idx(plru_direct_logic_next)
    );


    always_ff @( posedge clk ) begin
        if (rst) begin
            curr_state <= idle_state;
            shadow_to_cache_idx <= 'x;
        end
        else begin
            curr_state <= next_state;
            shadow_to_cache_idx <= to_cache_idx;
        end
    end


    always_ff @( posedge clk ) begin
        if (rst) begin
            s_ufp_addr <= '0;
            s_ufp_rmask <= '0;
            s_ufp_wmask <= '0;
            s_ufp_wdata <= '0;
        end
        else begin
            if(curr_state == idle_state || ufp_resp) begin
                s_ufp_addr <= ufp_addr;
                s_ufp_rmask <= ufp_rmask;
                s_ufp_wmask <= ufp_wmask;
                s_ufp_wdata <= ufp_wdata;
            end
        end
    end

    always_comb begin
        data_array_din = '{default: 'x};
        data_array_web = '{default: 1'b0};
        data_array_wmask = '{default: '0};

        tag_array_din = '{default: 'x};
        tag_array_web = '{default: 1'b0};

        valid_array_din = '{default: 'x};
        valid_array_web = '{default: 1'b0};

        // dirty_array_din = '{default: 'x};
        // dirty_array_web = '{default: 1'b0};

        plru_array_din = 'x;
        plru_array_web = 1'b0;

        hit = 1'b0;
        hit_index = 'x;

        ufp_rdata = 'x;
        ufp_resp = 1'b0;

        dfp_read = 1'b0;
        dfp_write = 1'b0;
        dfp_addr = 'x;
        dfp_wdata = 'x;

        next_state = curr_state;
        to_cache_idx = shadow_to_cache_idx;
        case (curr_state)
            /*idle_state,*/ default: begin
                if (ufp_rmask != '0 || ufp_wmask != '0) begin
                    next_state = compare_state;
                end

            end
            rw_dependency_state: begin
                next_state = compare_state;
                ufp_resp = 1'b0;
            end
            compare_state:      // freshly read data
                if (s_ufp_rmask != '0) begin
                    // read hits
                    for (int unsigned i = 0; i < NUM_WAYS; i++) begin
                        if (valid_array_dout[i] && (tag_array_dout[i][TAG_BITS-1:0] == s_ufp_addr[31:5 + SET_BITS])) begin
                            hit = 1'b1;
                            hit_index = WAY_BITS'(i);
                            // rmask not needed because that byte could be anything
                            ufp_rdata = data_array_dout[i][{s_ufp_addr[4:2], 2'b00} * 8 +: 32*SS_FETCH];        // potential out of bounds access issue
                            ufp_resp = 1'b1;                // i - 2 == i[1]
                            plru_array_din = plru_array_din_array[i]; // i > 1 ? {1'b1, hit_index[0], plru_array_dout[0]} : {1'b0, plru_array_dout[1], hit_index[0]};     // AB/CD bit, CD bit, AB bit
                            plru_array_web = 1'b1;

                            if(ufp_rmask == '0 && ufp_wmask == '0) begin
                                next_state = idle_state;
                            end
                            
                            else begin
                                next_state = compare_state;
                            end
                        end
                    end
                    // read misses, bring data
                    if (!hit) begin
                        to_cache_idx = plru_direct_logic_next; // {~plru_array_dout[2], ~plru_array_dout[~plru_array_dout[2]]};

                        // read dirty miss
                        if (valid_array_dout[to_cache_idx] && tag_array_dout[to_cache_idx][TAG_BITS] == 1'b1) begin 
                            next_state = wb_state;
                        end else begin// read clean miss
                            next_state = alloc_state;
                        end
                    end
                end else if (s_ufp_wmask != '0) begin
                    // write hits
                    for (int unsigned i = 0; i < NUM_WAYS; i++) begin
                        // still needs to have been a valid value
                        if (valid_array_dout[i] && (tag_array_dout[i][TAG_BITS-1:0] == s_ufp_addr[31:5 + SET_BITS])) begin
                            hit = 1'b1;
                            hit_index = WAY_BITS'(i);
                            data_array_wmask[i][{s_ufp_addr[4:2], 2'b00} +: 4] = s_ufp_wmask;
                            data_array_web[i] = 1'b1;       // doesn't matter if this was a dirty write already
                            data_array_din[i][{s_ufp_addr[4:2], 2'b00} * 8 +: 32] = s_ufp_wdata;
                            ufp_resp = 1'b1;
    
                            plru_array_din = plru_array_din_array[i]; // i > 1 ? {1'b1, hit_index[0], plru_array_dout[0]} : {1'b0, plru_array_dout[1], hit_index[0]};     // AB/CD bit, CD bit, AB bit
                            plru_array_web = 1'b1;

                            tag_array_web[i] = 1'b1;
                            tag_array_din[i] = {1'b1, tag_array_dout[i][TAG_BITS-1:0]};      // became dirty
                            
                            if(ufp_rmask == '0 && ufp_wmask == '0) begin
                                next_state = idle_state;
                            end
                            else if(ufp_rmask != '0) begin
                                next_state = rw_dependency_state;
                            end
                            
                            else begin
                                next_state = rw_dependency_state;
                            end
                        end
                    end
                    // write misses, bring then send data
                    if (!hit) begin
                        to_cache_idx = plru_direct_logic_next; // {~plru_array_dout[2], ~plru_array_dout[~plru_array_dout[2]]};
                        // dirty write miss
                        if (valid_array_dout[to_cache_idx] && tag_array_dout[to_cache_idx][TAG_BITS] == 1'b1) begin 
                            next_state = wb_state;
                        end else begin
                            next_state = alloc_state;
                        end
                    end
                    // write misses
                end

            alloc_state: begin
                // ask dmem
                dfp_read = 1'b1;
                dfp_addr = {s_ufp_addr[31:5], 5'b0};
                if (dfp_resp) begin
                    next_state = rw_dependency_state;

                    tag_array_web[to_cache_idx] = 1'b1;
                    tag_array_din[to_cache_idx] = {1'b0, s_ufp_addr[31:5 + SET_BITS]};

                    valid_array_web[to_cache_idx] = 1'b1;
                    valid_array_din[to_cache_idx] = 1'b1;

                    data_array_web[to_cache_idx] = 1'b1;
                    data_array_wmask[to_cache_idx] = '1;      // writing fully new data in cacheline
                    data_array_din[to_cache_idx] = dfp_rdata;
                end
            end
            wb_state: begin
                dfp_write = 1'b1;
                dfp_addr = {tag_array_dout[to_cache_idx][TAG_BITS-1:0], s_ufp_addr[5 + SET_BITS - 1 : 5], 5'b0};
                dfp_wdata = data_array_dout[to_cache_idx];
                if (dfp_resp) begin
                    next_state = alloc_state;
                    tag_array_web[to_cache_idx] = 1'b1;
                    tag_array_din[to_cache_idx] = {1'b0, tag_array_dout[to_cache_idx][TAG_BITS-1:0]};      // not dirty anymore
                end
            end
        endcase
    end

    always_ff @( posedge clk ) begin
        if (rst) begin
            i_cache_misses <= '0;
        end
        else if (dfp_read && dfp_resp) begin
            i_cache_misses <= i_cache_misses + 1'b1;
        end
    end


    logic [63:0] i_cache_hits;

    always_ff @ (posedge clk) begin
        if(rst) begin
            i_cache_hits <= '0;
        end
        else begin
            if(hit) begin
                i_cache_hits <= i_cache_hits + 'd1;
            end
        end
    end 

endmodule