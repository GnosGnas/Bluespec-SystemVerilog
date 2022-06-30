// Package for Systolic Matrix Multiplier 
// Usage: Feed the input matrices in the form of diagonals and the result is also got in a diagonal form
// Note: The module can be fairly easily pipelined but test bench is not made for that

`define MAT_DIM 3
`define bits_int 16
`define bits_frac 16

typedef FixedPoint#(`bits_int, `bits_frac) SysType;
typedef Vector#(`MAT_DIM, Vector#(`MAT_DIM, SysType)) MatType;
typedef Vector#(`MAT_DIM, SysType) VecType;

package SystolicMatrixMultiplier;
    import pe::*;
    import FixedPoint::*;

    interface Ifcmat_mult_systolic;
        method Action feed_inp_stream(VecType a_stream, VecType b_stream);
        method ActionValue#(VecType) get_out_stream;
        method Action reset_mod;
    endinterface

    (* synthesize *)
    module mkmat_mult_systolic(Ifcmat_mult_systolic);
        Vector#(`MAT_DIM, Vector#(`MAT_DIM, Ifc_pe)) pe <- replicateM(replicateM(mk_pe));

        Vector#(`MAT_DIM, Wire#(SysType)) wr_inp_a <- replicateM(mkDWire(unpack(0)));
        Vector#(`MAT_DIM, Wire#(SysType)) wr_inp_b <- replicateM(mkDWire(unpack(0)));
        PulseWire wr_inp_rdy <- mkPulseWire;
        Reg#(Bool) incr <- mkReg(False);

        Reg#(int) cntr <- mkReg(0);

        rule systole;
            SysType lv_pe_a[`MAT_DIM][`MAT_DIM];
            SysType lv_pe_b[`MAT_DIM][`MAT_DIM];

            if (wr_inp_rdy)
                // feed the new inputs to the systolic array
                for (int i = 0; i < `MAT_DIM; i = i + 1) begin
                    lv_pe_a[i][0] = wr_inp_a[i];
                    lv_pe_b[0][i] = wr_inp_b[i];

                    if (i != 0) begin
                        lv_pe_a[0][i] = pe[0][i - 1].getA();
                        lv_pe_b[i][0] = pe[i - 1][0].getB();
                    end
                end

            for (int i = 1; i < `MAT_DIM; i = i + 1)
                for (int j = 1; j < `MAT_DIM; j= j + 1) 
                    if (pe[i][j - 1].validAB && pe[i - 1][j].validAB) begin
                        lv_pe_a[i][j] = pe[i][j - 1].getA();
                        lv_pe_b[i][j] = pe[i - 1][j].getB();
                    end
                    else begin
                        lv_pe_a[i][j] = unpack(0);
                        lv_pe_b[i][j] = unpack(0); 
                    end               

            //propagate the systolic array
            for (int i = 0; i < `MAT_DIM; i = i + 1)
                for (int j = 0; j < `MAT_DIM; j= j + 1) begin
                    pe[i][j].putA(lv_pe_a[i][j]);
                    pe[i][j].putB(lv_pe_b[i][j]);

                end
        endrule

        rule inc_cntr (incr);
            if (cntr == 3*`MAT_DIM-1) begin
                cntr <= 0;
                incr <= False;
            end
            else
                cntr <= cntr+1;
        endrule

        method Action feed_inp_stream(VecType a_stream, VecType b_stream);
            //$display($time, "\nfeed_inp %d\n", cntr);
            for (int i = 0; i < `MAT_DIM; i = i + 1) begin
                wr_inp_a[i] <= a_stream[i];
                wr_inp_b[i] <= b_stream[i];
            end   

            incr <= True;

            wr_inp_rdy.send();
        endmethod


        method ActionValue#(VecType) get_out_stream if (cntr > `MAT_DIM);
            VecType out_stream = replicate(0);

            for (int i=0; i<`MAT_DIM; i=i+1) begin
                if (cntr-i-`MAT_DIM-1 < `MAT_DIM) begin
                    out_stream[i] = pe[i][cntr-i-`MAT_DIM-1].getC();
                    /*$display("\n", $time, "get_out:");
                    fxptWrite(5, out_stream[i]);
                    $display("\n");*/
                end
            end
            return out_stream;
        endmethod

        method Action reset_mod;
            for(int i=0; i<`MAT_DIM; i=i+1)
                for(int j=0; j<`MAT_DIM; j=j+1)
                    pe[i][j].reset_mod();
        endmethod

    endmodule
    
 /// Test bench for the module
    (* synthesize *)
    module tb_mat_mult(Empty);
        Ifc_mat_mult_systolic myMult <- mat_mult_systolic;

        Reg#(VecType) inp_Astream <- mkReg(unpack(0));
        Reg#(VecType) inp_Bstream <- mkReg(unpack(0));
        Reg#(VecType) out_stream <- mkReg(unpack(0));
        Reg#(int) rg_cntr <- mkReg(0);
        Vector#(`MAT_DIM, Vector#(`MAT_DIM, Reg#(SysType))) finalo <- replicateM(replicateM(mkReg(0)));

        SysType lv_mat_A[`MAT_DIM][`MAT_DIM];
        SysType lv_mat_B[`MAT_DIM][`MAT_DIM];

        lv_mat_A[0][0] = 1;
        lv_mat_A[0][1] = 2;
        lv_mat_A[0][2] = 3;

        lv_mat_A[1][0] = 4;
        lv_mat_A[1][1] = 5;
        lv_mat_A[1][2] = 6;

        lv_mat_A[2][0] = 7;
        lv_mat_A[2][1] = 8;
        lv_mat_A[2][2] = 9;

        lv_mat_B[0][0] = 1;
        lv_mat_B[0][1] = 2;
        lv_mat_B[0][2] = 3;

        lv_mat_B[1][0] = 4;
        lv_mat_B[1][1] = 5;
        lv_mat_B[1][2] = 6;

        lv_mat_B[2][0] = 7;
        lv_mat_B[2][1] = 8;
        lv_mat_B[2][2] = 9;

        rule cntr;
            rg_cntr <= rg_cntr + 1;
        endrule

        rule feed_stream;
            if (rg_cntr >= 1 && rg_cntr <= 5)
                myMult.feed_inp_stream(inp_Astream, inp_Bstream);

            if (rg_cntr == 20) $finish();
        endrule

        rule in_stream;
            VecType a_in = replicate(0);
            VecType b_in = replicate(0);

            VecType outp = replicate(0);
            //MatType output_mat = myMult.get_out_stream();

            for(int i=0; i<`MAT_DIM; i=i+1) begin
                if ((rg_cntr-i < `MAT_DIM) &&(i<=rg_cntr)) begin
                    a_in[i] = lv_mat_A[i][rg_cntr-i];
                    b_in[i] = lv_mat_B[rg_cntr-i][i];

                    //$display("\nlvA[%d, %d]\n", i, rg_cntr-i);
                    //fxptWrite(5, lv_mat_A[i][rg_cntr-i]);
                    $display("\na\n");
                    fxptWrite(5, a_in[i]);
                    $display("\nb\n");
                    fxptWrite(5, b_in[i]);
                end 
            end 

            inp_Astream <= a_in;
            inp_Bstream <= b_in;
            out_stream <= outp;
        endrule

        rule out_stream;
            let z = myMult.get_out_stream;
            VecType outr = z;
            $display("\nCount %d\n", rg_cntr);

            for (int i=0; i<`MAT_DIM; i=i+1) begin
                int k = rg_cntr-i-`MAT_DIM-7;
                $display("\nincoming %d\n", k);
                fxptWrite(5, outr[i]);


                if ((k>=0) && (k < `MAT_DIM)) begin
                    finalo[i][k] <= outr[i];
                    $display($time, " hooo %d,%d\n", i, k);
                end
            end
        endrule
    endmodule
endpackage
