
import ConfigReg::*;


function int norm_lookup (int inp);
	case(inp) matches
		2: return(11585);
		3: return(8192);
		4: return(5792);
		5: return(4096);
		6: return(2896);
	endcase
endfunction



function int cos128_lookup (int inp);
	case(inp) matches
		0: return 16384;
		1: return 16379;
		2: return 16364;
		3: return 16339;
		4: return 16305;
		5: return 16260;
		6: return 16206;
		7: return 16142;
		8: return 16069;
		9: return 15985;
		10: return 15892;
		11: return 15790;
		12: return 15678;
		13: return 15557;
		14: return 15426;
		15: return 15286;
		16: return 15136;
		17: return 14978;
		18: return 14810;
		19: return 14634;
		20: return 14449;
		21: return 14255;
		22: return 14053;
		23: return 13842;
		24: return 13622;
		25: return 13395;
		26: return 13159;
		27: return 12916;
		28: return 12665;
		29: return 12406;
		30: return 12139;
		31: return 11866;
		32: return 11585;
		33: return 11297;
		34: return 11002;
		35: return 10701;
		36: return 10393;
		37: return 10079;
		38: return 9759;
		39: return 9434;
		40: return 9102;
		41: return 8765;
		42: return 8423;
		43: return 8075;
		44: return 7723;
		45: return 7366;
		46: return 7005;
		47: return 6639;
		48: return 6269;
		49: return 5896;
		50: return 5519;
		51: return 5139;
		52: return 4756;
		53: return 4369;
		54: return 3980;
		55: return 3589;
		56: return 3196;
		57: return 2801;
		58: return 2404;
		59: return 2005;
		60: return 1605;
		61: return 1205;
		62: return 803;
		63: return 402;
		64: return 0;
	endcase
endfunction

function int cos128(int inp);
	int angle2 = unpack(pack(inp) & 32'd255);

	if (( angle2 >= 0) && (angle2 <= 64 ))
        return cos128_lookup(angle2);
    else if (( angle2 > 64) && (angle2 <= 128 ))
        return -1*cos128_lookup(128-angle2) ;
    else if (( angle2 > 128) && (angle2 <= 192 ))
        return -1*cos128_lookup(angle2-128);
    else
        return cos128_lookup(256-angle2);

endfunction


function int sin128(int inp);
	return cos128(inp - 64);
endfunction

function int round2(int x, Integer n); //Can change n to 14
	return (x+(1<<(n-1))) >> n;
endfunction

function int normalise(Integer n, int x);
	int temp = round2(x * norm_lookup(fromInteger(n)),14);
	return temp;
endfunction

function int brev (Integer bits, int inp_n);
	int result = 0;
	int n = inp_n;
	for (Integer i=0; i<bits; i=i+1) begin
		result = result << 1;
		result = result | n & 1;
		n = n >> 1;
	end

	return result;
endfunction

function Tuple2#(int, int) funcB (Tuple2#(int, int) inps, int angle, Bool flag);
	int ta = tpl_1(inps);
	int tb = tpl_2(inps);

	int x = ta*cos128(angle) - tb*sin128(angle);
	int y = ta*sin128(angle) + tb*cos128(angle);

	if (flag)
		return tuple2(round2(y,14), round2(x,14));
	else
		return tuple2(round2(x,14), round2(y,14));
endfunction

interface Ifc_butterfly; ////B
	method Action inps(int ta, int tb, int angle, Bool flag);
	method int ta;
	method int tb;
endinterface

module mkButterfly (Ifc_butterfly);
	Reg#(int) tanew <- mkReg(0), tbnew <- mkReg(0);
	Reg#(Bool) valid_outs <- mkReg(False);

	method Action inps(int ta, int tb, int angle, Bool flag);
		int x = ta*cos128(angle) - tb*sin128(angle);
		int y = ta*sin128(angle) + tb*cos128(angle);

		if (flag) begin //flag = 1
			tanew <= round2(y, 14);
			tbnew <= round2(x, 14);
		end
		else begin
			tanew <= round2(x, 14);
			tbnew <= round2(y, 14);
		end

		valid_outs <= True;
	endmethod

	method int ta if (valid_outs);
		return tanew;
	endmethod

	method int tb if (valid_outs);
		return tbnew;
	endmethod
endmodule

(*synthesize*)
module tb (Empty);
	Reg#(int) status <- mkReg(0);
	Ifc_butterfly mod <- mkButterfly;

	rule r1(status ==0);
		mod.inps(4, 7, 32-brev(5,4), False);
		status <= 1;
	endrule

	rule r2 (status==1);
		int ta = mod.ta;
		int tb = mod.tb;
		Tuple2#(int, int) tup = tuple2(4, 7);
		tup = funcB(tup, 32-brev(5,4), False);
		$display("diff %d-%d %d-%d", ta, tpl_1(tup), tb, tpl_2(tup));
		$finish;
	endrule
endmodule

function Tuple2#(int, int) funcH (Tuple2#(int, int) inps, Bool flag);
	int ta = tpl_1(inps);
	int tb = tpl_2(inps);

	if (flag)
		return tuple2(tb-ta, ta+tb);
	else
		return tuple2(ta+tb, ta-tb);
endfunction

interface Ifc_Hadamard; ///H
	method Action inps(int ta, int tb, Bool flag);
	method int ta;
	method int tb;
endinterface

module mkHadamard (Ifc_Hadamard);
	Reg#(int) tanew <- mkConfigReg(0), tbnew <- mkConfigReg(0);
	Reg#(Bool) valid_outs <- mkReg(False);

	method Action inps(int ta, int tb, Bool flag);
		if (flag) begin		//flag = 1
			tanew <= tb - ta;
			tbnew <= ta + tb;
		end
		else begin
			tanew <= ta + tb;
			tbnew <= ta - tb;
		end

		valid_outs <= True;
	endmethod

	method int ta if (valid_outs);
		return tanew;
	endmethod

	method int tb if (valid_outs);
		return tbnew;
	endmethod
endmodule