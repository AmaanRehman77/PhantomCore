module cache_adapter (
    input   logic clk, rst, 
    output  logic   [31:0]  bmem_addr,
    output  logic           bmem_read,
    output  logic           bmem_write,
    input   logic   [63:0]  bmem_rdata,
    output  logic   [63:0]  bmem_wdata,
    input   logic           bmem_resp,
    input   logic           bmem_ready,
    input   logic   [31:0]  bmem_raddr,

    input   logic   [31:0]  dfp_addr,
    input   logic           dfp_read,
    input   logic           dfp_write,
    output  logic   [255:0] dfp_rdata,
    output  logic   [31:0]  dfp_raddr,
    input   logic   [255:0] dfp_wdata,
    output  logic           dfp_r_resp, dfp_w_resp
);

logic [1:0] read_resp_counter, write_resp_counter;
logic [63:0] data1, data2, data3;


always_ff @( posedge clk ) begin
    if (rst) begin
        read_resp_counter <= '0;
        write_resp_counter <= '0;
    end

    if (bmem_resp) begin
        read_resp_counter <= read_resp_counter + 1'b1;
    end

    if (read_resp_counter == 2'b00) begin
        data1 <= bmem_rdata;
    end
    if (read_resp_counter == 2'b01) begin
        data2 <= bmem_rdata;
    end
    if (read_resp_counter == 2'b10) begin
        data3 <= bmem_rdata;
    end

    if(bmem_write && bmem_ready) begin
        write_resp_counter <= write_resp_counter + 1'b1;
    end

end

always_comb begin

    bmem_addr = dfp_addr;
    bmem_read = dfp_read;
    bmem_write = dfp_write;

    bmem_wdata = dfp_wdata[write_resp_counter*64 +: 64];

    dfp_r_resp = '0;
    dfp_w_resp = '0;
    dfp_rdata = 'x;

    dfp_raddr = bmem_raddr;

    if (read_resp_counter == 2'b11) begin
        dfp_r_resp = '1;
        dfp_rdata = {bmem_rdata, data3, data2, data1};
    end

    if(write_resp_counter == 2'b11) begin
        dfp_w_resp = '1;
    end
    
end


endmodule : cache_adapter