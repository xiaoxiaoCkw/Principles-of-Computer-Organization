`timescale 1ns / 1ps

module cache (
    // 全局信号
    input             clk,
    input             reset,
    // 从CPU来的访问信号
    input wire [12:0] addr_from_cpu,    // CPU来的地址
    input wire        rreq_from_cpu,    // CPU来的读请求
    input wire        wreq_from_cpu,    // CPU来的写请求
    input wire [7:0]  wdata_from_cpu,   // CPU来的写数据
    // 从下层内存模块来的信号
    input wire [31:0] rdata_from_mem,   // 内存读取的数据
    input wire        rvalid_from_mem,  // 内存读取数据可用标志
    // 输出给CPU的信号
    output wire [7:0] rdata_to_cpu,     // 输出给CPU的数据
    output wire       hit_to_cpu,       // 输出给CPU的命中标志
    // 输出给下层内存模块的信号
    output reg        rreq_to_mem,      // 输出给下层内存模块的读请求
    output reg [12:0] raddr_to_mem,     // 输出给下层模块的突发传输首地址
    output reg        wreq_to_mem,      // 输出给下层内存模块的写请求
    output reg [12:0] waddr_to_mem,     // 输出给下层内存模块的写地址
    output reg [ 7:0] wdata_to_mem      // 输出给下层内存模块的写数据
);

reg [3:0] r_current_state, r_next_state, w_current_state, w_next_state;
localparam R_READY     = 4'b0000,
           R_TAG_CHECK = 4'b0001,
           REFILL      = 4'b0010,
           W_READY     = 4'b0011,
           W_TAG_CHECK = 4'b0100,
           WR_MEM      = 4'b0101;
           
reg wreq;   // 写请求信号
reg whit;   // 写命中标志

wire        wea;                        // Cache写使能信号
wire [37:0] cache_line_r;               // 待写入Cache的Cache行数据
wire [37:0] cache_line;                 // 从Cache中读出的Cache行数据

wire [ 4:0] tag_from_cpu   = addr_from_cpu[12:8];        // 主存地址的Tag
wire [ 5:0] cache_index    = addr_from_cpu[7:2];         // 主存地址中的Cache索引/Cache地址
wire [ 1:0] offset         = addr_from_cpu[1:0];         // Cache行内的字节偏移
wire        valid_bit      = cache_line[37];             // Cache行的有效位
wire [ 4:0] tag_from_cache = cache_line[36:32];          // Cache行的Tag

wire hit  = ((r_current_state == R_TAG_CHECK) || (w_current_state == W_TAG_CHECK)) && valid_bit && (tag_from_cache == tag_from_cpu);
wire miss = (tag_from_cache != tag_from_cpu) | (~valid_bit);

assign cache_line_r = (whit) ? ((offset == 2'b00) ? {1'b1, addr_from_cpu[12:8], cache_line[31:8], wdata_from_cpu[7:0]}  :
                                 (offset == 2'b01) ? {1'b1, addr_from_cpu[12:8], cache_line[31:16], wdata_from_cpu[7:0], cache_line[7:0]}  :
                                 (offset == 2'b10) ? {1'b1, addr_from_cpu[12:8], cache_line[31:24], wdata_from_cpu[7:0], cache_line[15:0]} :
                                 {1'b1, addr_from_cpu[12:8], wdata_from_cpu[7:0], cache_line[23:0]}) : {1'b1, addr_from_cpu[12:8], rdata_from_mem[31:0]};
                                        
// 根据Cache行的字节偏移，从Cache块中选取CPU所需的字节数据
assign rdata_to_cpu = (rreq_from_cpu && hit) ? ((offset == 2'b00) ? cache_line[7:0]  :
                                                 (offset == 2'b01) ? cache_line[15:8]  :
                                                 (offset == 2'b10) ? cache_line[23:16] : cache_line[31:24]) : 8'b0;

assign hit_to_cpu = hit;

// 使用Block RAM IP核作为Cache的物理存储体
blk_mem_gen_0 u_cache (
    .clka   (clk         ),
    .wea    (wea         ),
    .addra  (cache_index ),
    .dina   (cache_line_r),
    .douta  (cache_line  )
);

// 保存CPU来的写请求信号
always @(posedge clk) begin
    if (reset) begin
        wreq <= 1'b0;
    end
    else if (wreq_from_cpu) begin
        wreq <= 1'b1;
    end
    else begin
        wreq <= 1'b0;
    end
end

// 生成写命中标志
always @(posedge clk) begin
    if (reset) begin
        whit <= 1'b0;
    end
    else if (wreq && hit) begin
        whit <= 1'b1;
    end
    else begin
        whit <= 1'b0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        r_current_state <= R_READY;
        w_current_state <= W_READY;
    end
    else begin
        r_current_state <= r_next_state;
        w_current_state <= w_next_state;
    end
end

// 根据指导书/PPT的状态转换图，实现控制Cache读取的状态转移
always @(*) begin
    case(r_current_state)
        R_READY: begin
            if (rreq_from_cpu) begin
                r_next_state = R_TAG_CHECK;
            end 
            else begin
                r_next_state = R_READY;
            end
        end
        R_TAG_CHECK: begin 
            if (hit) begin
                r_next_state = R_READY;
            end
            else begin
                r_next_state = REFILL;
            end
        end
        REFILL: begin
            if (rvalid_from_mem) begin
                r_next_state = R_TAG_CHECK;
            end
            else begin 
                r_next_state = REFILL;
            end
        end
        default: begin
            r_next_state = R_READY;
        end
    endcase
end

// 控制Cache写入的状态转移
always @(*) begin
    case(w_current_state)
        W_READY: begin
            if (wreq_from_cpu) begin
                w_next_state = W_TAG_CHECK;
            end 
            else begin
                w_next_state = W_READY;
            end
        end
        W_TAG_CHECK: begin 
            if (hit) begin
                w_next_state = WR_MEM;
            end
            else begin
                w_next_state = W_READY;
            end
        end
        WR_MEM: begin
            w_next_state = W_READY;
        end
        default: begin
            r_next_state = W_READY;
        end
    endcase
end

// 生成Block RAM的写使能信号
assign wea = ((r_current_state == REFILL) && rreq_from_cpu) || ((w_current_state == WR_MEM) && wreq);

// 生成读取主存所需的信号，即读请求信号rreq_to_mem和读地址信号raddr_to_mem
always @(posedge clk) begin
    if (reset) begin
        raddr_to_mem <= 13'b0;
        rreq_to_mem <= 1'b0;
    end
    else begin
        case (r_next_state)
            R_READY: begin
                raddr_to_mem <= 13'b0;
                rreq_to_mem  <= 1'b0;
            end
            R_TAG_CHECK: begin
                raddr_to_mem <= addr_from_cpu;
                rreq_to_mem  <= 1'b0;
            end
            REFILL: begin
                raddr_to_mem <= raddr_to_mem;
                rreq_to_mem  <= 1'b1;
            end
            default: begin
                raddr_to_mem <= 13'b0;
                rreq_to_mem  <= 1'b0;
            end
        endcase
    end
end

// 写命中处理（写直达法）
/* TODO */
always @(posedge clk) begin
    if (reset) begin
        wreq_to_mem <= 1'b0;
        waddr_to_mem <= 13'b0;
        wdata_to_mem <= 8'b0;
    end
    else begin
        case(w_next_state)
            W_READY: begin
                wreq_to_mem <= 1'b0;
                waddr_to_mem <= 13'b0;
                wdata_to_mem <= 8'b0;
            end
            W_TAG_CHECK: begin
                wreq_to_mem <= 1'b0;
                waddr_to_mem <= 13'b0;
                wdata_to_mem <= 8'b0;
            end
            WR_MEM: begin
                wreq_to_mem <= 1'b1;
                waddr_to_mem <= addr_from_cpu;
                wdata_to_mem <= wdata_from_cpu;
            end
        endcase
    end
end

endmodule
