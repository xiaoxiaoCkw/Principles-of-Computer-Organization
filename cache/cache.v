`timescale 1ns / 1ps

module cache (
    // ȫ���ź�
    input             clk,
    input             reset,
    // ��CPU���ķ����ź�
    input wire [12:0] addr_from_cpu,    // CPU���ĵ�ַ
    input wire        rreq_from_cpu,    // CPU���Ķ�����
    input wire        wreq_from_cpu,    // CPU����д����
    input wire [7:0]  wdata_from_cpu,   // CPU����д����
    // ���²��ڴ�ģ�������ź�
    input wire [31:0] rdata_from_mem,   // �ڴ��ȡ������
    input wire        rvalid_from_mem,  // �ڴ��ȡ���ݿ��ñ�־
    // �����CPU���ź�
    output wire [7:0] rdata_to_cpu,     // �����CPU������
    output wire       hit_to_cpu,       // �����CPU�����б�־
    // ������²��ڴ�ģ����ź�
    output reg        rreq_to_mem,      // ������²��ڴ�ģ��Ķ�����
    output reg [12:0] raddr_to_mem,     // ������²�ģ���ͻ�������׵�ַ
    output reg        wreq_to_mem,      // ������²��ڴ�ģ���д����
    output reg [12:0] waddr_to_mem,     // ������²��ڴ�ģ���д��ַ
    output reg [ 7:0] wdata_to_mem      // ������²��ڴ�ģ���д����
);

reg [3:0] r_current_state, r_next_state, w_current_state, w_next_state;
localparam R_READY     = 4'b0000,
           R_TAG_CHECK = 4'b0001,
           REFILL      = 4'b0010,
           W_READY     = 4'b0011,
           W_TAG_CHECK = 4'b0100,
           WR_MEM      = 4'b0101;
           
reg wreq;   // д�����ź�
reg whit;   // д���б�־

wire        wea;                        // Cacheдʹ���ź�
wire [37:0] cache_line_r;               // ��д��Cache��Cache������
wire [37:0] cache_line;                 // ��Cache�ж�����Cache������

wire [ 4:0] tag_from_cpu   = addr_from_cpu[12:8];        // �����ַ��Tag
wire [ 5:0] cache_index    = addr_from_cpu[7:2];         // �����ַ�е�Cache����/Cache��ַ
wire [ 1:0] offset         = addr_from_cpu[1:0];         // Cache���ڵ��ֽ�ƫ��
wire        valid_bit      = cache_line[37];             // Cache�е���Чλ
wire [ 4:0] tag_from_cache = cache_line[36:32];          // Cache�е�Tag

wire hit  = ((r_current_state == R_TAG_CHECK) || (w_current_state == W_TAG_CHECK)) && valid_bit && (tag_from_cache == tag_from_cpu);
wire miss = (tag_from_cache != tag_from_cpu) | (~valid_bit);

assign cache_line_r = (whit) ? ((offset == 2'b00) ? {1'b1, addr_from_cpu[12:8], cache_line[31:8], wdata_from_cpu[7:0]}  :
                                 (offset == 2'b01) ? {1'b1, addr_from_cpu[12:8], cache_line[31:16], wdata_from_cpu[7:0], cache_line[7:0]}  :
                                 (offset == 2'b10) ? {1'b1, addr_from_cpu[12:8], cache_line[31:24], wdata_from_cpu[7:0], cache_line[15:0]} :
                                 {1'b1, addr_from_cpu[12:8], wdata_from_cpu[7:0], cache_line[23:0]}) : {1'b1, addr_from_cpu[12:8], rdata_from_mem[31:0]};
                                        
// ����Cache�е��ֽ�ƫ�ƣ���Cache����ѡȡCPU������ֽ�����
assign rdata_to_cpu = (rreq_from_cpu && hit) ? ((offset == 2'b00) ? cache_line[7:0]  :
                                                 (offset == 2'b01) ? cache_line[15:8]  :
                                                 (offset == 2'b10) ? cache_line[23:16] : cache_line[31:24]) : 8'b0;

assign hit_to_cpu = hit;

// ʹ��Block RAM IP����ΪCache������洢��
blk_mem_gen_0 u_cache (
    .clka   (clk         ),
    .wea    (wea         ),
    .addra  (cache_index ),
    .dina   (cache_line_r),
    .douta  (cache_line  )
);

// ����CPU����д�����ź�
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

// ����д���б�־
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

// ����ָ����/PPT��״̬ת��ͼ��ʵ�ֿ���Cache��ȡ��״̬ת��
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

// ����Cacheд���״̬ת��
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

// ����Block RAM��дʹ���ź�
assign wea = ((r_current_state == REFILL) && rreq_from_cpu) || ((w_current_state == WR_MEM) && wreq);

// ���ɶ�ȡ����������źţ����������ź�rreq_to_mem�Ͷ���ַ�ź�raddr_to_mem
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

// д���д���дֱ�﷨��
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
