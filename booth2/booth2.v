module booth2 (
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
reg  [34:0] a_reg1, s_reg1, a_reg2, s_reg2, p_reg, sum_reg;
reg  [4:0]  iter_cnt;

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
			if (iter_cnt == 3'd7) 	next_state = OUTPUT;
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

// modified booth algorithm
always @ (posedge clk or negedge rst_n) begin
	if (~rst_n) begin
		a_reg1 <= 35'b0;
		s_reg1 <= 35'b0;
		a_reg2 <= 35'b0;
		s_reg2 <= 35'b0;
		p_reg <= 35'b0;
		sum_reg <= 35'b0;
		iter_cnt <= 5'b0;
		z <= 32'b0;
	end
	else begin
		case (current_state)
			IDLE: begin
				a_reg1 <= {{(2){x[15]}}, x, {(17){1'b0}}};		// 2's complement of x
				s_reg1 <= {-{{(2){x[15]}}, x}, {(17){1'b0}}};   // 2's complement of -x
				a_reg2 <= {{x[15], x, 1'b0}, {(17){1'b0}}};		// 2's complement of 2x
				s_reg2 <= {-{x[15], x, 1'b0}, {(17){1'b0}}};	// 2's complement of -2x
				p_reg <= {{(18){1'b0}}, y, 1'b0};  				// partial product
				iter_cnt <= 5'b0;
			end
			ADDANDSHIFT: begin
				case (p_reg[2:0])
					3'b000:	sum_reg = p_reg;
					3'b001:	sum_reg = p_reg + a_reg1;
					3'b010:	sum_reg = p_reg + a_reg1;
					3'b011:	sum_reg = p_reg + a_reg2;
					3'b100:	sum_reg = p_reg + s_reg2;
					3'b101:	sum_reg = p_reg + s_reg1;
					3'b110:	sum_reg = p_reg + s_reg1;
					3'b111:	sum_reg = p_reg;
				endcase
				iter_cnt = iter_cnt + 1'b1;
				p_reg = {{(2){sum_reg[34]}}, sum_reg[34:2]};
			end
			OUTPUT: begin
				z <= p_reg[32:1];
				busy <= 1'b0;
			end
		endcase
	end
end

endmodule