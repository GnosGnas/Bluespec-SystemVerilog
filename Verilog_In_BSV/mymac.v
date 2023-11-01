
module mymac(EN, a, b, clear_value, clear, out, clk, rst_b);
	input [15:0] a, b, clear_value;
	input EN, clear, clk, rst_b;
	output [15:0] out;

	reg [15:0] out;
	wire [15:0] a, b, clear_value;

	always@(posedge clk or negedge rst_b)
		if (!rst_b)
		out <= 0;
		else
		out <= clear ? clear_value : (EN ? out+a*b: out);
endmodule