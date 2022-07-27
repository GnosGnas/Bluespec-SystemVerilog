package IDCT_pipelined;
	import Modules::*;
	import Vector::*;
	import ConfigReg::*;

	//for arrays mkDWire(0) or mkReg(0) //mkWire can be also be used with caution if it uses lesser resources
	//for flags mkDWire or mkReg(False)

	//input stage
	`define inp_array mkDWire(0) 
	`define stg0_flag mkDWire(False)

	//stage 0
	`define stg0_array mkReg(0)
	`define stg1_flag mkReg(False)

	//stage 1
	`define stg1_array mkReg(0)
	`define stg2_flag mkReg(False)

	//stage 2
	`define stg2_array mkReg(0)
	`define stg3_flag mkReg(False)

	//stage 3
	`define stg3_array mkReg(0)
	`define stg4_flag mkReg(False)

	interface Ifc_IDCT#(numeric type n, numeric type n1); //n1 is number of bits required to represent n - can be computed from log(n) too maybe
		method Action t_input (Vector#(n, int) inp_vec, Bit#(n1) opr_mode);
		method Vector#(n, int) t_read;
		method Bool read_valid;
	endinterface

	//(*synthesize*)
	module mkIDCT_4 (Ifc_IDCT#(4, 0));
		//input vars
		Vector#(4, Reg#(int)) t_inp_array <- replicateM(`inp_array); 
		Reg#(Bool) stage0 <- `stg0_flag; 

		//stg0 vars
		Vector#(4, Reg#(int)) store_stg0 <- replicateM(`stg0_array);
		Reg#(Bool) stage1 <- `stg1_flag; 

		//stg1 vars
		Vector#(4, Reg#(int)) store_stg1 <- replicateM(`stg1_array);  
		Reg#(Bool) stage2 <- `stg2_flag;  

		//Stage 0
		rule rl_stg0 (stage0);
			//$display($time, "stg0: values %d, %d, %d, %d", t_inp_array[0], t_inp_array[1], t_inp_array[2], t_inp_array[3]);
			Tuple2#(int, int) temp1 = tuple2(t_inp_array[0], t_inp_array[1]);
			temp1 = funcB(temp1, 32, True);

			store_stg0[0] <= tpl_1(temp1);
			store_stg0[1] <= tpl_2(temp1);

			Tuple2#(int, int) temp2 = tuple2(t_inp_array[2], t_inp_array[3]);
			temp2 = funcB(temp2, 64 - brev(6, 2), False);
			
			store_stg0[2] <= tpl_1(temp2);
			store_stg0[3] <= tpl_2(temp2);

			stage1 <= True;
		endrule

		rule reset_stage1 (!stage0);
			stage1 <= False;
		endrule

		//Stage 1
		rule rl_stg1 (stage1);
			//$display($time, "stg1: values %d, %d, %d, %d", store_stg0[0], store_stg0[1], store_stg0[2], store_stg0[3]);
			Vector#(2, Tuple2#(int, int)) temp = defaultValue;
			
			for (int i=0; i<2; i=i+1) begin
				temp[i] = tuple2(store_stg0[i], store_stg0[3-i]);
				temp[i] = funcH(temp[i], False);

				store_stg1[i] <= tpl_1(temp[i]);
				store_stg1[3-i] <= tpl_2(temp[i]);
			end

			stage2 <= True;
		endrule

		rule reset_out (!stage1);
			stage2 <= False;
		endrule

		method Action t_input (Vector#(4, int) inp_vec, Bit#(0) opr_mode);
			// dont care abt opr_mode like before
			for (int i=0; i<4; i=i+1)
				t_inp_array[i] <= inp_vec[i];
			
			stage0 <= True;
		endmethod

		method Vector#(4, int) t_read; 
			Vector#(4, int) temp = defaultValue;
			for (int i=0; i<4; i=i+1)
				temp[i] = store_stg1[i];
			return temp;
		endmethod 

		method Bool read_valid = stage2;
	endmodule

	//(*synthesize*)
	module mkIDCT_8 (Ifc_IDCT#(8, 2));
		Ifc_IDCT#(4, 0) mod_4 <- mkIDCT_4;

		//input vars
		Vector#(4, Reg#(int)) t_inp_array <- replicateM(`inp_array); 
		Reg#(Bool) stage0 <- `stg0_flag; 

		//stg0 vars
		Vector#(4, Reg#(int)) store_stg0 <- replicateM(`stg0_array);  
		Reg#(Bool) stage1 <- `stg1_flag; 

		//stg1 vars
		Vector#(4, Reg#(int)) store_stg1 <- replicateM(`stg1_array);  
		Reg#(Bool) stage2_8 <- `stg2_flag;
		Bool stage2_4 = mod_4.read_valid;

		//stg2 vars
		Vector#(8, Reg#(int)) store_stg2 <- replicateM(`stg2_array);  
		Reg#(Bool) stage3_4 <- `stg3_flag, stage3_8 <- `stg3_flag;

		//stg3 vars
		Vector#(8, Reg#(int)) store_stg3 <- replicateM(`stg3_array);  
		Reg#(Bool) stage4 <- `stg4_flag;

		//Stage 0
		rule rl_stg0 (stage0);
			Vector#(2, Tuple2#(int, int)) temp = defaultValue;

			for (int i=0; i<2; i=i+1) begin
				temp[i] = tuple2(t_inp_array[4+i-4], t_inp_array[8-1-i-4]);
				temp[i] = funcB(temp[i], 32-brev(5, 4+i), False);

				store_stg0[4+i-4] <= tpl_1(temp[i]);
				store_stg0[8-1-i-4] <= tpl_2(temp[i]);
				$display("%d - %d, %d", i, tpl_1(temp[i]), tpl_2(temp[i]));
			end
			$finish;

			stage1 <= True;
		endrule

		rule reset_stage1 (!stage0);
			stage1 <= False;
		endrule

		//Stage 1
		rule rl_stg1 (stage1);
			$display($time, "stg1: values %d, %d, %d, %d", store_stg0[0], store_stg0[1], store_stg0[2], store_stg0[3]);
			Vector#(2, Tuple2#(int, int)) temp = defaultValue;

			for (int i=0; i<2; i=i+1) begin
				temp[i] = tuple2(store_stg0[4+2*i-4], store_stg0[4+2*i+1-4]);
				if (i==0)
					temp[i] = funcH(temp[i], False);
				else
					temp[i] = funcH(temp[i], True);
				
				store_stg1[4+2*i-4] <= tpl_1(temp[i]);
				store_stg1[4+1+2*i-4] <= tpl_2(temp[i]);
			end

			stage2_8 <= True;
		endrule

		rule reset_stage2 (!stage1);
			stage2_8 <= False;
		endrule

		//Stage 2
		rule rl_stg2;
			if (stage2_4) begin
				let temp_vec = mod_4.t_read;
				for(int i=0; i<4; i=i+1)
					store_stg2[i] <= temp_vec[i];
				
				stage3_4 <= True;
				$display($time, "stg2_4: values %d, %d, %d, %d", temp_vec[0], temp_vec[1], temp_vec[2], temp_vec[3]);
			end
			else
				stage3_4 <= False;

			if (stage2_8) begin
				Tuple2#(int, int) temp = defaultValue;
				
				temp = tuple2(store_stg1[8-1-1-4], store_stg1[4+1-4]);
				temp = funcB(temp, 16, True);

				store_stg2[8-1-1] <= tpl_1(temp); //6
				store_stg2[4+1] <= tpl_2(temp);  //5

				store_stg2[4] <= store_stg1[0];
				store_stg2[7] <= store_stg1[3];

				stage3_8 <= True;
				$display($time, "stg2_8: values %d, %d, %d, %d", store_stg1[0], tpl_1(temp), tpl_2(temp), store_stg1[3]);
			end
			else 
				stage3_8 <= False;
		endrule

		//Stage 3
		rule rl_stg3_8 (stage3_8);
			//$display($time, "stg1: values %d, %d, %d, %d", store_stg0[0], store_stg0[1], store_stg0[2], store_stg0[3]);
			Vector#(4, Tuple2#(int, int)) temp = defaultValue;

			for (int i=0; i<4; i=i+1) begin
				temp[i] = tuple2(store_stg2[i], store_stg2[8-1-i]);
				temp[i] = funcH(temp[i], False);

				store_stg3[i] <= tpl_1(temp[i]);
				store_stg3[8-1-i] <= tpl_2(temp[i]);			
			end

			stage4 <= True;
		endrule

		rule rl_stg3_4 (stage3_4 && (!stage3_8));
			for (int i=0; i<8; i=i+1)
				store_stg3[i] <= store_stg2[i];

			stage4 <= True;
		endrule

		rule reset_stage4 ((!stage3_4) && (!stage3_8));
			stage4 <= False;
		endrule

		method Action t_input (Vector#(8, int) inp_vec, Bit#(2) opr_mode);
			Vector#(4, int) mod4_inp = defaultValue;

			for (int i=0; i<4; i=i+1) begin
				mod4_inp[i] = inp_vec[i];
				t_inp_array[i] <= inp_vec[i+4];
			end

			mod_4.t_input(mod4_inp, 0);

			if (opr_mode == 2'd3)
				stage0 <= True;
		endmethod

		method Vector#(8, int) t_read;
			Vector#(8, int) temp = defaultValue;
			for (int i=0; i<8; i=i+1)
				temp[i] = store_stg3[i];
			return temp;
		endmethod 

		method Bool read_valid = stage4;
	endmodule


	(*synthesize*)
	module mkTestBench (Empty);
		Ifc_IDCT#(8, 2) dut <- mkIDCT_8;
		Reg#(int) stage <- mkReg(0), ct <- mkReg(0);

		rule initialier (stage==0);
			Vector#(8, int) temp = defaultValue;
			for (int i=0; i<8; i=i+1)
				temp[i] = i;

			$display($time, "inp1");
			dut.t_input(temp, 2'd3);
			stage <= 1;
		endrule

		rule init2(stage == 1);
			stage <= 2;
		endrule

		rule initialier2 (stage==2);
			Vector#(8, int) temp = defaultValue;
			for (int i=0; i<8; i=i+1)
				temp[i] = 2*i;
			$display($time, "inp2");
			dut.t_input(temp, 2'd3);
			stage <= 3;
		endrule

		rule starter (dut.read_valid);
			let out = dut.t_read;
			ct <= ct+1;
			$display($time, "values");
			for (int i=0; i<8;i=i+1) begin
				$display("T[%d]=%d",i, out[i]);
			end
			if (ct == 0) $finish;
		endrule

	endmodule
endpackage
