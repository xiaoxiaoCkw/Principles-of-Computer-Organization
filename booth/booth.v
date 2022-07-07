 module booth (
    input  wire        clk  ,
	input  wire        rst_n,
	input  wire [15:0] x    ,
	input  wire [15:0] y    ,
	input  wire        start,
	output reg  [31:0] z    ,
	output reg         busy 
);

parameter	IDLE   		= 2'b00,
			ADDANDSHIFT = 2'b01,
			OUTPUT 		= 2'b10;

reg  [1:0]  current_state, next_state;
reg  [33:0] a_reg, s_reg, p_reg, sum_reg;
reg  [4:0]  iter_cnt;
wire [16:0] x_neg;

// negetive value of x
assign x_neg = -{x[15], x};

// busy
always @ (posedge clk or negedge rst_n) begin
	if (~rst_n)		busy <= 1'b0;
	else if (start) busy <= 1'b1;
end

always @ (posedge clk or negedge rst_n) begin
	if (~rst_n)	current_state <= IDLE;
	else		current_state <= next_state;
end

// state transform
always @ (*) begin
	case (current_state)
		IDLE: begin
			if (start)	next_state = ADDANDSHIFT;
			else		next_state = IDLE;
		end
		ADDANDSHIFT: begin
			if (iter_cnt == 5'd16) 	next_state = OUTPUT;
		    else 					next_state = ADDANDSHIFT;
		end
		OUTPUT:	begin
			next_state = IDLE;
		end
		default: begin
			next_state = IDLE;
		end
	endcase
end

// booth algorithm
always @ (posedge clk or negedge rst_n) begin
	if (~rst_n) begin
		a_reg <= 34'b0;
		s_reg <= 34'b0;
		p_reg <= 34'b0;
		sum_reg <= 34'b0;
		iter_cnt <= 5'b0;
		z <= 32'b0;
	end
	else begin
		case (current_state)
			IDLE: begin
				a_reg <= {x[15], x, {(17){1'b0}}}; // 2's complement of x
				s_reg <= {x_neg, {(17){1'b0}}};    // 2's complement of -x
				p_reg <= {{(17){1'b0}}, y, 1'b0};  // partial product
				iter_cnt <= 5'b0;
			end
			ADDANDSHIFT: begin
				// add 16 times
				case (p_reg[1:0])
					2'b00:	sum_reg = p_reg;
					2'b01:	sum_reg = p_reg + a_reg;
					2'b10:	sum_reg = p_reg + s_reg;
					2'b11:	sum_reg = p_reg;
				endcase
				iter_cnt = iter_cnt + 1'b1;
				// shift 15 times
				if (iter_cnt <= 4'd15) p_reg = {sum_reg[33], sum_reg[33:1]};
			end
			OUTPUT: begin
				z <= sum_reg[33:2];
				busy <= 1'b0;
			end
		endcase
	end
end

endmodule
