package Matrix_Multiplication1;

//Libraries which are imported for the package. Package FloatingPoint is required only when floating point data type is used.
import CBus::*;
import Vector::*;
//import FloatingPoint::*;


//Parameters to control the modules
typedef 8 Addr_size;					//This is the size of each memory address.
typedef 32 Data_size;					//This is the size of each word. Log of this value is used in the test bench.
typedef 10 Max_mat;						//This is the maximum size of the vector the hardware accelerator can operate on. It is limited by the memory size.
typedef TExp#(Addr_size) Mem_size;		//This is total size of the memory in words. It's value is 2^Addr_size.


//Some parts of the module require integer forms of the parameters which are declared here
int size_addr = fromInteger(valueOf(Addr_size));
int size_data = fromInteger(valueOf(Data_size));
int size_mem = fromInteger(valueOf(Mem_size));
int max_mat = fromInteger(valueOf(Max_mat));

//Input type of the data. The constraint on this the size should match with Data_size. Preferred types are int and Float (of FloatingPoint Package).
typedef int M_type;		   

//Values used for testing purposes.
int v0 = 5;  				
int vd = 6;  
//Float v0 = unpack(32'h3fc00000);  //1.5
//Float vd = unpack(32'h3f000000);  //0.5


//Defining the type of Module.
typedef ModWithCBus#(Addr_size, Data_size, i) MyModWithCBus#(type i);
typedef CBus#(Addr_size, Data_size) MyCBus;

//This is the special structure used for CBus type registers. Addr_size is the size of component 'a' and log2(Data_size) is the size of component 'o'. The Control Status Register of the matrix multiplier can have values from 0 to 4 so it needs to be atleast 3 bits, so the Data_size value should be atleast 8.
typedef CRAddr#(Addr_size, Data_size) DCAddr;	


//////Test Bench///////////////////////////////////////////

//Test Bench module to pass the address of the matrices in the memory and to keep track of the status of the Matrix multiplier

(* synthesize *)
module mkTestBench(Empty);
    let matrix_ifc();
    mkMatrix_Multiplier_Synth matrix_module(matrix_ifc());

    Reg#(Bit#(Addr_size)) addressA <- mkReg(4);
    Reg#(Bit#(Addr_size)) addressB <- mkReg(2);
    Reg#(Bit#(Addr_size)) destination_address <- mkReg(100);
    Reg#(int) matrix_size <- mkReg(3);

    Reg#(int) testing_stage <- mkReg(0);
    Reg#(Maybe#(Bit#(32))) csr_matrix <- mkReg(tagged Invalid);

    //This rule reads the value of the CSR of the matrix module. The read function returns a 32 bit number (which is of size log(Data_size)) whose last bits contain the actual data stored in the CSR of the matrix module.
	//The remaining bits have the address of the register. If Data_size value is changed in the type definition, then log(Data_size)-1 needs to be used instead of 4 in slicing of csr_matrix.
    rule reader;
    	let csr_read <- matrix_ifc.cbus_ifc.read(13);
    	csr_matrix <= tagged Valid(csr_read);
    endrule

    rule stage0 ( (testing_stage==0) && (isValid(csr_matrix)) );
    	if( csr_matrix.Valid[4:0]==0 )
    	begin
    		testing_stage <= 1;
    	end

    	else
    	begin
    		$display("Matrix multiplier is unavailable");
    		$finish;
    	end
    endrule

    rule stage1 ( testing_stage==1 );
		matrix_ifc.device_ifc.put_addressA(addressA);
		matrix_ifc.device_ifc.put_addressB(addressB);
		matrix_ifc.device_ifc.size_of_mat(matrix_size);
		matrix_ifc.device_ifc.put_destination_address(destination_address);

		$display("Address of A[0,0] is %d and address of B[0,0] is %d. \nThe destination address starts at %d. The size of the matrices is %d.\nThe time at which the addresses are sent is ",addressA, addressB, destination_address, matrix_size,$time);

		testing_stage <= 2;
    endrule

    rule stage2 ( testing_stage==2 );
    	if( csr_matrix.Valid[4:0]==4 )
    	begin
    		$display("Error in inputs");
    		$finish;
    	end

    	else if( csr_matrix.Valid[4:0]==3 )
    	begin
    		testing_stage <= 3;
    	end
    endrule

    rule stage3 (testing_stage==3);
    	if( csr_matrix.Valid[4:0]==0 )
    	begin
    		$display("\nMatrix multiplication has been completed.\nTime at which it completed - ",$time);
    		$finish;    	
    	end
    endrule
endmodule
/////////////////////////////////////////////////////////////



//////MEMORY MODULE//////////////////////////////////////////

// First, we implement a simple memory. There are four interfaces. MIDR interface is to pass data to be stored in a particular location in the memory. 
// This location is passed to the module with the MAR interface. MAR interface is also used to pass the address of the memory from where data needs to be read.
// MODR interface returns the data stored in that address and MODR_ready tells the module if the value is ready or not.
// There are two ways to interface with the memory module. Above interfaces are accessed via front-door interfacing and the control register of the memory module is accessed via back-door interfacing using CBus with the associated address 11. 
// The control register has two significant bits (present at CR[1:0]). The 0th bit is for read/write operation (0 for read and 1 for write). The first bit is for enabling memory operations (1 for enabling). When the memory is not being used, the control register's value is 0.

interface Memory_ifc;
    method Action midr(Bit#(Data_size) inp);
    method ActionValue#(Bit#(Data_size)) modr;
    method Action mar(Bit#(Addr_size) address);
    method Bool modr_ready;
endinterface

//This module allows us to make a synthesizable memory module.
(*synthesize*)
module mkMemorySynth(IWithCBus#(MyCBus, Memory_ifc));
    let ifc();
    exposeCBusIFC#(mkMemory) _temp(ifc);
    return (ifc);
endmodule

module [MyModWithCBus] mkMemory(Memory_ifc);
    Vector#(Mem_size, Reg#(Bit#(Data_size))) memory_element <- replicateM(mkReg(0));

    Reg#(Bit#(Data_size)) data_in <- mkReg(0);        		//Register to get input data
    Reg#(Bit#(Data_size)) data_out <- mkReg(0);       		//Register to return output data
    Reg#(Bit#(Addr_size)) address_value <- mkReg(0);  		//Register to store the location address

    DCAddr temp = DCAddr{a:11,o:0};           				//A temporary variable to initialise the control register
    Reg#(DCAddr) control_register <- mkCBRegRW(temp, 11);   //Control register of the memory with an associated address 11.
    Reg#(Bool) flag_output <- mkReg(False);     			//Flag to indicate if the output is ready


    ////THIS PART OF THE CODE IS TO INITIALISE THE MEMORY MODULE WITHIN ITSELF.
    Reg#(Bool) enable_initialise <- mkReg(True);            //Register used to enable initialisation for module purposes

    //Initialising the memory with a series of values to test our module
    rule initialising_rule if(enable_initialise);  
        for(int i=0;i< size_mem - 1;i=i+1)
            memory_element[i]<= pack(v0+(i*vd));
        enable_initialise <= False;
    endrule 
    ////


    //This rule resets the control register if its value is not 0, 2 or 3
    rule reset_control_register if( (pack(control_register.o)!=0) && 
                                    (pack(control_register.o)!=2) &&
                                    (pack(control_register.o)!=3) );
        control_register.o <= 0;
    endrule

	//This tells the compiler that both reading and writing cannot happen in the same cycle
    (*preempts="read_memory,write_memory"*)  

   	//Reading is done when the control register's last two bits are 2'b10 (which is 2 in decimal)
    rule read_memory if( (control_register.o==unpack(2)) && (!enable_initialise) );
        data_out <= memory_element[address_value];
        control_register.o <= 0;
        flag_output <= True;
    endrule

	// Writing is done when the control register is 2'b11 (which is 3 in decimal)
    rule write_memory if( (control_register.o==unpack(3)) && (!enable_initialise) );
        memory_element[address_value] <= data_in;
        control_register.o <= 0;
    endrule


    method Action midr(Bit#(Data_size) inp) if( (control_register.o==unpack(0)) && (!enable_initialise) );
            data_in <= inp;
    endmethod
	
    method ActionValue#(Bit#(Data_size)) modr if( (flag_output) && (!enable_initialise) );
        flag_output <= False;
        return data_out;
    endmethod
	
    method Bool modr_ready if( (!enable_initialise) );
        return flag_output;
    endmethod
	
    method Action mar(Bit#(Addr_size) address) if( (control_register.o==unpack(0)) && (!enable_initialise) );
        address_value <= address;
    endmethod  
	
endmodule
/////////////////////////////////////////////////////////////



///////Matrix Module///////////////////

// This is the module for matrix multiplication. The module recieves the addresses of the first element of both the input matrices and also recieves the size of these input matrices.
// Then it uses the inner vector module for vector dot multiplication. The values recieved from the memory are stored and continuosly passed to the vector module.
// Before going to the next row, first all the columns of the second matrix are passed and are multipllied with the previous row. This is repeated till all the rows are passed.
// The module has four input ports for getting the location and destination addresses and the size of the matrices.
// An assumption was made that all the elements of the first matrix are row-wise contiguous and all the elements of the second matrix are column-wise contiguous in the memory.
// The final resulting matrix is also stored row-wise contiguously in the memory starting at the destination address given to this module.
// The status of the module can be received by reading the Control Status Register of the matrix module through back-door interfacing with the associated address 13.
// CSR of the matrix module can have values upto 4. When the matrix is not operational, the value is 0. When it is operational, the CSR tells the stage at which the matrix is in.
// If the CSR value is 4, then it means that the inputs given to the module have an error like if the address value of some elements are not in the memory


interface Matrix_ifc;
    method Action put_addressA (Bit#(Addr_size) addr1);     		//Method to put the address of the first element of the first vector
    method Action put_addressB (Bit#(Addr_size) addr2);     		//Method to put the address of the first element of the second vector
    method Action size_of_mat (int m);                      		//Method to put the size of the matrices
    method Action put_destination_address (Bit#(Addr_size) dest); 	//Method to put the starting destination address for the resulting matrix
endinterface

//This module allows us to make a synthesizable outer module for matrix multiplication.
(*synthesize*)
module mkMatrix_Multiplier_Synth(IWithCBus#(MyCBus, Matrix_ifc));
    let ifc();
    exposeCBusIFC#(mkMatrix_Multiplier) _temp(ifc);
    return (ifc);
endmodule

module [MyModWithCBus] mkMatrix_Multiplier(Matrix_ifc);
    Reg#(Maybe#(Bit#(Addr_size))) addressA <- mkReg(tagged Invalid);    			//Register to store address of an element of A
    Reg#(Maybe#(Bit#(Addr_size))) addressB <- mkReg(tagged Invalid);    			//Register to store address of an element of B
    Reg#(Maybe#(Bit#(Addr_size))) destination_address <- mkReg(tagged Invalid);    	//Register to store address of an element of the resulting matrix
    Reg#(Maybe#(int)) matrix_size <- mkReg(tagged Invalid);             			//Register to store size of the matrices
    Reg#(Maybe#(int)) num_elements <- mkReg(tagged Invalid);               			//Register to store the total number of elements in the matrices

    DCAddr temp = DCAddr{ a:13, o:0 };          	  //A temporary variable to initialise CSR_matrix
    Reg#(DCAddr) csr_matrix <- mkCBRegR(temp, 13);    //Control Status Register of the matrix module with associated address 13

    Vector#(Max_mat, Reg#(M_type)) matrix1 <- replicateM(mkReg(unpack(0)));       //Register array to store first matrix
    Vector#(Max_mat, Reg#(M_type)) matrix2 <- replicateM(mkReg(unpack(0)));       //Register array to store second matrix
    Vector#(Max_mat, Reg#(M_type)) result_matrix <- replicateM(mkReg(unpack(0))); //Register array to store resulting matrix

    Reg#(Bool) enable_getA <- mkReg(False); //Register to enable the rule to retrieve an element of A from memory
    Reg#(Bool) enable_getB <- mkReg(False); //Register to enable the rule to retrieve an element of B from memory
    Reg#(Bit#(1)) enableAB <- mkReg(0);     //Register used to enable the alternating retrieval of elements of A and B
    Reg#(int) pos<- mkReg(0);               //Register used to store position of an element in a matrix

    Reg#(int) scaled_rowA <- mkReg(0);
    Reg#(int) scaled_colB <- mkReg(0);
    Reg#(int) k <- mkReg(0);

    Vector_inner_ifc#(M_type) vector_module <- mkVector_inner;

    //This is the declaration of the interface used to connect to the memory module via CBus
    let memory_ifc();
    mkMemorySynth memory_module(memory_ifc());


    //Stage 1
    //Rules to pass the address and store the value retrieved from the memory into the respective registers. A and B elements are received parallely so that 'pos' can be used for both A and B elements.
    
	rule pass_addrA if( (csr_matrix.o==unpack(0)) && (isValid(num_elements)) && 
                        (isValid(addressA)) && (enableAB==0) && (!enable_getA) );
        memory_ifc.device_ifc.mar(addressA.Valid); 
        memory_ifc.cbus_ifc.write(11, unpack(2));
        enable_getA <= True;
    endrule

    rule getA if( (csr_matrix.o==unpack(0)) && (enable_getA) && (enableAB==0) && 
                   (memory_ifc.device_ifc.modr_ready()) ); 
        let a_value <- memory_ifc.device_ifc.modr();
        matrix1[pos] <= unpack(a_value);
        enable_getA <= False;
        enableAB <= 1;
    endrule

    rule pass_addrB if( (csr_matrix.o==unpack(0)) && (isValid(num_elements)) && 
                        (isValid(addressB)) && (enableAB==1) && (!enable_getB) );
        memory_ifc.device_ifc.mar(addressB.Valid);
        memory_ifc.cbus_ifc.write(11, unpack(2));
        enable_getB <= True;
    endrule

    rule getB if( (csr_matrix.o==unpack(0)) && (enable_getB) && (enableAB==1) && 
    			  (memory_ifc.device_ifc.modr_ready()) ); 
        let b_value <- memory_ifc.device_ifc.modr();
        matrix2[pos] <= unpack(b_value);
        enable_getB <= False;
        enableAB <= 0;

        if( pos==num_elements.Valid-1 ) 
        begin
            pos <= 0;   		//Here it is initialised so that it can be reused
            addressA <= tagged Invalid;
            addressB <= tagged Invalid;
            csr_matrix.o <= 1;
        end

        else 
        begin
            pos <= pos+1;
            addressA <= tagged Valid(addressA.Valid + 1);
            addressB <= tagged Valid(addressB.Valid + 1);

            if( (addressA.Valid==pack((size_mem-1))[size_addr-1:0]) || 
                (addressB.Valid==pack((size_mem-1))[size_addr-1:0]) )  //This is for fail check
                csr_matrix.o <= 4;     //Reading this will indicate the CPU that the inputs were invalid
        end        
    endrule

    //Rule to reset the module, if the inputs are invalid which is indicated when the CSR value is 4.
    rule reset_csr_4 if( csr_matrix.o==unpack(4) );
        csr_matrix.o <= 0;
        addressA <= tagged Invalid;
        addressB <= tagged Invalid;
        destination_address <= tagged Invalid;
        matrix_size <= tagged Invalid;
        num_elements <= tagged Invalid;
    endrule


    //Stage 2
    //Here, instead of multiplying matrix_size and scaled_rowA, scaled_rowA is added with matrix_size after each row of values have been passed. Similarly scaled_colB also gets added with matrix_size.

    rule pass_AB if( (scaled_rowA < num_elements.Valid) && (scaled_colB < num_elements.Valid) && (csr_matrix.o==unpack(1)) );
        if( (k<matrix_size.Valid) )
        begin
            vector_module.put_a(matrix1[scaled_rowA+k]);
            vector_module.put_b(matrix2[scaled_colB+k]);

            if( k==(matrix_size.Valid-1) )
            begin
                vector_module.end_value(True);
                k <= 0; 

                if( scaled_colB==(num_elements.Valid-matrix_size.Valid) ) 
                begin
                    scaled_rowA <= scaled_rowA+matrix_size.Valid;
                    scaled_colB <= 0;
                end

                else scaled_colB <= scaled_colB+matrix_size.Valid;
            end    

            else 
            begin
                vector_module.end_value(False);
                k <= k+1;
            end                                  
        end
    endrule

    //This tells the compliler that get_results and pass_AB are not to be executed in the same cycle and the priority is given to get_results. This was required else get_results rule gets shadowed.
    (*preempts="get_results,pass_AB"*)
    (*fire_when_enabled*)
    rule get_results if( (vector_module.final_done()) && (csr_matrix.o==unpack(1)) && (pos<num_elements.Valid) );
        let value <- vector_module.dot_result();
        result_matrix[pos] <= value; 

        if(pos==num_elements.Valid-1) 
        begin
            csr_matrix.o <= 2;
            pos <= 0;
        end

        else pos <= pos+1;
    endrule


    //Stage 3
    //Once the elements of the resulting matrix are received they are stored in the memory. As storing in memory takes two cycles, the results from the vector module had to be stored and a buffer rule has also been used for letting the memory to store the value. 

    rule store_results if( (csr_matrix.o==unpack(2)) && (pos<num_elements.Valid) && (isValid(destination_address)) );    
        memory_ifc.device_ifc.midr(pack(result_matrix[pos]));
        memory_ifc.device_ifc.mar(destination_address.Valid);
        memory_ifc.cbus_ifc.write(11, unpack(3));

        destination_address <= tagged Valid(destination_address.Valid+1); 
        pos <= pos+1;
        csr_matrix.o <= 3;     //This is just to create a buffer cycle as writing into the memory takes 2 cycles
    endrule


    //Stage 4
    rule buffer_reset if( csr_matrix.o==unpack(3) );
        if(pos==num_elements.Valid)
        begin
            csr_matrix.o <= 0;
            pos <= 0;
            num_elements <= tagged Invalid;
            destination_address <= tagged Invalid;
        end

        else csr_matrix.o <= 2;
    endrule


    //Rules to display the input matrices and the resulting matrix. Values are displayed row-wise. To display floating point values comment the rules used to display integer values and uncomment the rules used to display floating point values.
    Reg#(int) scaled_pos1 <- mkReg(0);
    Reg#(int) pos2 <- mkReg(0);
    Reg#(int) scaled_pos2 <- mkReg(0);
    Reg#(int) pos1 <- mkReg(0);
    Reg#(Bit#(2)) switch <- mkReg(0);


    ////To display integer values.
    rule display_input_A if( (csr_matrix.o==unpack(1)) && (switch==0) );
        $display("a[%d,%d] = %d", ( (scaled_pos1/matrix_size.Valid)+1 ), ( pos2+1 ), matrix1[scaled_pos1+pos2]);


        if(pos2==matrix_size.Valid-1)
        begin
            pos2 <= 0;

            if(scaled_pos1==(num_elements.Valid-matrix_size.Valid) )
            begin
                scaled_pos1 <= 0;
                switch <= 1;
                $display("\n");
            end

            else
                scaled_pos1 <= scaled_pos1+matrix_size.Valid;
        end

        else
            pos2 <= pos2+1;
    endrule

    rule display_input_B if( (csr_matrix.o==unpack(1)) && (switch==1) );
        $display("b[%d,%d] = %d", ( pos2+1 ), ( (scaled_pos1/matrix_size.Valid)+1 ), matrix2[scaled_pos1+pos2]);

        if( scaled_pos1==(num_elements.Valid-matrix_size.Valid) )
        begin
            scaled_pos1 <= 0;

            if(pos2==(matrix_size.Valid-1) )
            begin
                pos2 <= 0;
                switch <= 2;
                $display("\n");
            end

            else
                pos2 <= pos2+1;
        end

        else
            scaled_pos1 <= scaled_pos1+matrix_size.Valid;
    endrule

    rule display_output if( (csr_matrix.o==unpack(2)) && (switch==2) );
        $display("r[%d,%d] = %d", (scaled_pos1/matrix_size.Valid+1), pos2+1, result_matrix[scaled_pos1+pos2]);

        if(pos2==matrix_size.Valid-1)
        begin
            pos2 <= 0;

            if(scaled_pos1==(num_elements.Valid-matrix_size.Valid) )
            begin
                scaled_pos1 <= 0;
                switch <= 0;
            end

            else
                scaled_pos1 <= scaled_pos1+matrix_size.Valid;
        end

        else
            pos2 <= pos2+1;
    endrule
    ////

    /* Uncomment the following code if working with floating point values
    ////To display floating point values
    rule display_input_A if( (csr_matrix.o==unpack(1)) && (switch==0) );
        $display("a[%d,%d] = ", ( (scaled_pos1/matrix_size.Valid)+1 ), ( pos2+1 ), fshow(matrix1[scaled_pos1+pos2]));

        if(pos2==matrix_size.Valid-1)
        begin
            pos2 <= 0;

            if(scaled_pos1==(num_elements.Valid-matrix_size.Valid) )
            begin
                scaled_pos1 <= 0;
                switch <= 1;
                $display("\n");
            end

            else
                scaled_pos1 <= scaled_pos1+matrix_size.Valid;
        end

        else
            pos2 <= pos2+1;
    endrule

    rule display_input_B if( (csr_matrix.o==unpack(1)) && (switch==1) );
        $display("b[%d,%d] = ", ( pos2+1 ), ( (scaled_pos1/matrix_size.Valid)+1 ), fshow(matrix2[scaled_pos1+pos2]));

        if( scaled_pos1==(num_elements.Valid-matrix_size.Valid) )
        begin
            scaled_pos1 <= 0;

            if(pos2==(matrix_size.Valid-1) )
            begin
                pos2 <= 0;
                switch <= 2;
                $display("\n");
            end

            else
                pos2 <= pos2+1;
        end

        else
            scaled_pos1 <= scaled_pos1+matrix_size.Valid;
    endrule

    rule display_output if( (switch==2) );
        $display("r[%d,%d] = ", (scaled_pos1/matrix_size.Valid+1), pos2+1, fshow(result_matrix[scaled_pos1+pos2]));

        if(pos2==matrix_size.Valid-1)
        begin
            pos2 <= 0;

            if(scaled_pos1==(num_elements.Valid-matrix_size.Valid) )
            begin
                scaled_pos1 <= 0;
                switch <= 0;
            end

            else
                scaled_pos1 <= scaled_pos1+matrix_size.Valid;
        end

        else
            pos2 <= pos2+1;
    endrule
    ////
    */


    method Action put_addressA (Bit#(Addr_size) a1) if(csr_matrix.o==unpack(0));
        addressA <= tagged Valid(a1);
    endmethod
	
    method Action put_addressB (Bit#(Addr_size) a2) if(csr_matrix.o==unpack(0));
        addressB <= tagged Valid(a2);
    endmethod    
	
    method Action size_of_mat (int m) if(csr_matrix.o==unpack(0));
        matrix_size <= tagged Valid(m);
        num_elements <= tagged Valid(m*m);
    endmethod
	
    method Action put_destination_address (Bit#(Addr_size) dest) if(csr_matrix.o==unpack(0));
        destination_address <= tagged Valid(dest);
    endmethod
	
endmodule
///////////////////////////////////////////////////////////////


///////Inner Module for Vector Multiplication////////////////

// This is the inner module which performs the vector dot multiplication in a pipelined manner. The module has three input ports and two output ports.
// Two input ports get each element of the vectors and the third input port tells the module if the input values is the last of the vector. 
// "accum_sum" register stores the accumulated sum of the products of past inputs and when the flag becomes true then the sum is passed to the output port. 
// Boolean True is also passed and can be used as an indicator for output using the method "final_done".


interface Vector_inner_ifc#(type t);
    method Action put_a (t input1);			//Method to put the value of an element of the first vector.
    method Action put_b (t input2);			//Method to put the value of an element of the second vector.
    method Action end_value (Bool d_a);		//Method to pass the flag to indicate if the inputs passed are the last
    method ActionValue#(t) dot_result;  	//The final result can be received from here and is enabled only when the output is ready
    method Bool final_done;					//Method to check if output is ready
endinterface

(* synthesize *)
module mkVector_inner(Vector_inner_ifc#(M_type));
	
	//Stage 1 registers
    Reg#(Maybe#(M_type)) a <- mkReg(tagged Invalid);
    Reg#(Maybe#(M_type)) b <- mkReg(tagged Invalid);
    Reg#(Bool) flag_stage1 <- mkReg(True);  

    //Stage 2 registers
    Reg#(Maybe#(M_type)) prod <- mkReg(unpack(0));		
    Reg#(M_type) accum_sum    <- mkReg(unpack(0));
    Reg#(M_type) final_result <- mkReg(unpack(0));
    Reg#(Bool) flag_stage2    <- mkReg(True);

    //Stage 3 registers
    Reg#(Bool) flag_stage3 <- mkReg(True);
    Reg#(Bool) done        <- mkReg(False);


    //Stage 1
    rule stage1_multiplication;
        if( isValid(a) && isValid(b) )
        begin
        	prod <= tagged Valid( a.Valid * b.Valid );
        	flag_stage2 <= flag_stage1;

        	a <= tagged Invalid;			//This is done so that the next stage doesn't get junk or repeated values
        	b <= tagged Invalid;			//This also means that the values need not be passed continously

        end

        else
        begin
        	prod <= tagged Invalid;
        	flag_stage2 <= True;			//Reset value is being given to flag_stage2
        end
    endrule


    //Stage 2
    rule stage2_accumulated_sum ( isValid(prod) );
        final_result <= accum_sum + prod.Valid;

        if( flag_stage2 ) 
        begin
        	done <= True;
        	accum_sum <= 0;					//Reset is being given to accum_sum
        end

        else 
        begin
        	accum_sum <= accum_sum + prod.Valid;
        	done <= False;
        end

        flag_stage3 <= flag_stage2;
    endrule


    method Action put_a (M_type input1);
        a <= tagged Valid(input1);
    endmethod
	
    method Action put_b (M_type input2);
        b <= tagged Valid(input2);
    endmethod
	
    method Action end_value (Bool d_a);
        flag_stage1 <= d_a;
    endmethod


    //Stage 3
    method ActionValue#(M_type) dot_result if (flag_stage3);
    	flag_stage3 <= False;	
        return final_result;
    endmethod
	
    method Bool final_done;
        return done;
    endmethod
	
endmodule
/////////////////////////////////////////////////////////////


endpackage
