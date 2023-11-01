interface Mac_IFC ;
	method Action acc (Int#(16) a, Int#(16) b);
	method Action reset_acc (Int#(16) value);
	method Int#(16) read_y;
endinterface

import "BVI" mymac =
module mkMac (Mac_IFC);
	default_clock clk (clk);
	default_reset reset (rst_b);

	method acc(a, b) enable(EN);
	method reset_acc(clear_value) enable(clear);
	method out read_y();

	schedule (read_y) SB (reset_acc, acc);
	schedule (acc) C (reset_acc);
	schedule (read_y) CF (read_y);
	schedule (acc) C (acc);
	schedule (reset_acc) CF (reset_acc);
endmodule

(*synthesize*)
module mkTb (Empty);
	Mac_IFC dut <- mkMac;
	Reg#(int) cntr <- mkReg(0);

	rule r1 if (cntr < 3);
		cntr <= cntr+1;
		if (cntr == 0) begin
			dut.reset_acc(0);
		end
		else begin
			dut.acc(2, 3);
			$display("Sending 3");
		end
	endrule
	
	rule r2 if (cntr == 3);
		let z = dut.read_y;

		$display("Result is %d\n", z);
		$finish;
	endrule
endmodule