
package Vector_Multiplication;

//Libraries which are imported for the package. Package FloatingPoint is required only when floating point data type is used.
import CBus::*;
import Vector::*;
//import FloatingPoint::*;


//Parameters to control the modules
typedef 8 Addr_size;        //This is the size of each memory address.
typedef 32 Data_size;       //This is the size of each word. Log of this value is used in the test bench.
typedef 100 Max_vec;         //This is the maximum size of the vector the hardware accelerator can operate on. It is limited by the memory size.
typedef TExp#(Addr_size) Mem_size;      //This is total size of the memory in words. It's value is 2^Addr_size.


//Some places require integer forms of the parameters which are declared here
int size_addr = fromInteger(valueOf(Addr_size));
int size_data = fromInteger(valueOf(Data_size));
int size_mem = fromInteger(valueOf(Mem_size));
int max_vec = fromInteger(valueOf(Max_vec));


typedef int M_type;        //Input type of the data. The constraint on this the size should match with Data_size. Preferred types are int and Float (of FloatingPoint Package).


//Values used for testing purposes
int v0 = 5;  				
int vd = 6;  
//Float v0 = unpack(32'h3fc00000);  //1.5
//Float vd = unpack(32'h3f000000);  //0.5


//Defining the type of Module here.
typedef ModWithCBus#(Addr_size, Data_size, i) MyModWithCBus#(type i);
typedef CBus#(Addr_size, Data_size) MyCBus;

//This is the special structure used for CBus type registers. Addr_size is the size of component 'a' and log2(Data_size) is the size of component 'o'.
typedef CRAddr#(Addr_size, Data_size) DCAddr;   


//////Test Bench///////////////////////////////////////////

//Test Bench module to pass the address of the vectors in the memory and to keep track of the status of the Vector multiplier

(* synthesize *)
module mkTestBench(Empty);
    let vector_ifc();
    mkVector_Outer_Synth vector_module(vector_ifc());

    Reg#(Bit#(Addr_size)) addressA <- mkReg(4);
    Reg#(Bit#(Addr_size)) addressB <- mkReg(2);
    Reg#(Bit#(Addr_size)) destination_address <- mkReg(100);
    Reg#(int) vector_size <- mkReg(3);

    Reg#(int) testing_stage <- mkReg(0);
    Reg#(Maybe#(Bit#(32))) csr_vector <- mkReg(tagged Invalid);

   rule reader;
        let csr_read <- vector_ifc.cbus_ifc.read(12);
        csr_vector <= tagged Valid(csr_read);
    endrule

    rule stage0 ( (testing_stage==0) && (isValid(csr_vector)) );
        if( csr_vector.Valid[4:0]==0 )
        begin
            testing_stage <= 1;
        end

        else
        begin
            $display("Vector multiplier is unavailable");
            $finish;
        end
    endrule

    rule stage1 ( testing_stage==1 );
        vector_ifc.device_ifc.put_addressA(addressA);
        vector_ifc.device_ifc.put_addressB(addressB);
        vector_ifc.device_ifc.size_of_vector(vector_size);
        vector_ifc.device_ifc.put_destination_address(destination_address);

        $display("Address of A[0] is %d and address of B[0] is %d. \nThe destination address is %d. The size of the vectors is %d.\nThe time at which the addresses are sent is ",addressA, addressB, destination_address, vector_size,$time);

        testing_stage <= 2;
    endrule

    rule stage2 ( testing_stage==2 );
        if( csr_vector.Valid[4:0]==4 )
        begin
            $display("Error in inputs");
            $finish;
        end

        else if( csr_vector.Valid[4:0]==3 )
        begin
            $display("\nVector multiplication has been completed. \ntime at which it completed - ",$time);
            $display("\n");
            testing_stage <= 3;
        end
    endrule
endmodule
/////////////////////////////////////////////////////////////



//////MEMORY MODULE//////////////////////////////////////////

// First, we implement a simple memory. There are four interfaces. 
// MIDR interface is to pass data to be stored in a particular location in the memory. 
// This location is passed to the module with the MAR interface.
// MAR interface is also used to pass the address of the memory from where data needs to be read.
// MODR interface returns the data stored in that address and MODR_ready tells the module if the value is ready or not.
// There are two ways to interface with the memory module. Above interfaces are accessed via front-door interfacing and the control register of the memory module is accessed via back-door interfacing using CBus with the associated address 11. 
// The control register has two significant bits (present at CR[1:0]).
// The 0th bit is for read/write operation (0 for read and 1 for write). The first bit is for enabling memory operations (1 for enabling). When the memory is not being used, the control register's value is 0.


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

    Reg#(Bit#(Data_size)) data_in <- mkReg(0);        //Register to get input data
    Reg#(Bit#(Data_size)) data_out <- mkReg(0);       //Register to return output data
    Reg#(Bit#(Addr_size)) address_value <- mkReg(0);  //Register to store the location address

    DCAddr temp = DCAddr{a:11,o:0};                         //A temporary variable to initialise the control register
    Reg#(DCAddr) control_register <- mkCBRegRW(temp, 11);   //Control register of the memory with an associated address 11.
    Reg#(Bool) flag_output <- mkReg(False);                 //Flag to indicate if the output is ready


    ////THIS PART OF THE CODE IS TO INITIALISE THE MEMORY MODULE WITHIN ITSELF.
    Reg#(Bool) enable_initialise <- mkReg(True);            //Register used to enable initialisation for module purposes

    //Initialising the memory with a series of values to test our module
    rule initialising_rule if(enable_initialise);  
        for(int i=0;i< size_mem - 1;i=i+1)
            memory_element[i]<= pack(v0+(i*vd));
        enable_initialise <= False;
    endrule 
    ////


    //This rule resets the control register if its value is not
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



//////Vector Modules/////////////////////////////////////////
//////Outer Module for Vector Multiplication/////////////////

// This is the outer module which gets all the elements from the memory and passes it to the inner module for calculation. 
// The module has four input ports. 
// For this module we have taken that all the elements of a vector are contiguous in the memory with the input address of location of the first element of the vector at the first location. 
// The final dot product of the two vectors is stored in the destination address given to this module. 
// The elements are received from the memory in an alternating manner so that they need not be stored and are immediately passed to the inner module for the computations. 


interface Vector_Outer_ifc;
    method Action put_addressA (Bit#(Addr_size) addr1);		//Method to put the address of the first element of the first vector
    method Action put_addressB (Bit#(Addr_size) addr2);		//Method to put the address of the first element of the second vector
    method Action size_of_vector (int v);					//Method to put the size of the vectors
    method Action put_destination_address (Bit#(Addr_size) dest);	//Method to put the destination address for the result
endinterface

//This module allows us to make a synthesizable outer module for vector multiplication.
(*synthesize*)
module mkVector_Outer_Synth(IWithCBus#(MyCBus, Vector_Outer_ifc));
    let ifc();
    exposeCBusIFC#(mkVector_Outer) _temp(ifc);
    return (ifc);
endmodule

module [MyModWithCBus] mkVector_Outer(Vector_Outer_ifc);
    Reg#(Maybe#(Bit#(Addr_size))) addressA <- mkReg(tagged Invalid);	//Register to store address of an element of A
    Reg#(Maybe#(Bit#(Addr_size))) addressB <- mkReg(tagged Invalid);	//Register to store address of an element of B
    Reg#(Maybe#(Bit#(Addr_size))) destination_address <- mkReg(tagged Invalid);	//Register to store the destination address
    Reg#(Maybe#(int)) vector_size <- mkReg(tagged Invalid);				//Register to store size of the vectors

    DCAddr temp = DCAddr{ a:12, o:0 };                //A temporary variable to initialise CSR_vector
    Reg#(DCAddr) csr_vector <- mkCBRegR(temp, 12);    //Control Status Register of the vector outer module with associated address 12

    Reg#(Bool) enable_getA <- mkReg(False);	    //Register to enable the rule to retrieve an element of A from memory
    Reg#(Bool) enable_getB <- mkReg(False);	    //Register to enable the rule to retrieve an element of B from memory
    Reg#(Bit#(1)) enableAB <- mkReg(0);		    //Register used to enable the alternating retrieval of elements of A and B

    Reg#(M_type) dot_value <- mkReg(unpack(0));	//Register to store the final result received from the inner module

    Vector_Inner_ifc#(M_type) vector_inner <- mkVector_Inner;	//Declaration of the inner module

    //This is the declaration of the interface used to connect to the memory module via CBus
    let memory_ifc();
    mkMemorySynth memory_module(memory_ifc());


    //Stage 0

    //Rule to check if the inputs are valid

    rule input_check if( (isValid(addressA)) && (isValid(addressB)) && 
                         (isValid(vector_size)) && (isValid(destination_address)) && 
                         (csr_vector.o==unpack(0)) );
        if( (addressA.Valid < ( pack(size_mem)[size_addr-1:0]-(pack(vector_size.Valid)[size_addr-1:0]) ) ) && 
            (addressB.Valid < ( pack(size_mem)[size_addr-1:0]-(pack(vector_size.Valid)[size_addr-1:0]) ) ) && 
            ( (vector_size.Valid <= max_vec ) || (vector_size.Valid==0) ) )
        begin
            csr_vector.o <= 1;
        end

        else
        begin
            csr_vector.o <= 4; 	//This will indicate to the CPU that the inputs where invalid and further calculations where aborted.
            addressA <= tagged Invalid;
            addressB <= tagged Invalid;
            vector_size <= tagged Invalid;
            destination_address <= tagged Invalid;
        end
    endrule

    //Rule to reset the module, if the inputs are invalid which is indicated when the CSR value is 4
    rule if_csr_4 (csr_vector.o==unpack(4));
    	csr_vector.o <= 0;
    endrule


    //Stage 1

    //The rules here get the elements from the memory and pass it immediately to the inner module. These rules are repeated till all the values are received and passed to the inner module.

	rule pass_addressA_to_memory if( (csr_vector.o==unpack(1)) && (!enable_getA) && 
                                     (enableAB==0) && (isValid(addressA)) );
        memory_ifc.device_ifc.mar(addressA.Valid); 
        memory_ifc.cbus_ifc.write(11, unpack(2)); 
        enable_getA <= True;
    endrule

    rule getA_from_memory if( (enable_getA) && (enableAB==0) && 
                              (memory_ifc.device_ifc.modr_ready) );
    	let a_value <- memory_ifc.device_ifc.modr();
    	vector_inner.put_a(unpack(a_value));
    	enable_getA <= False;
    	enableAB <= 1;
    endrule

    rule pass_addressB_to_memory if( (csr_vector.o==unpack(1)) && (!enable_getB) && 
                                     (enableAB==1) && (isValid(addressB)) );
        memory_ifc.device_ifc.mar(addressB.Valid); 
        memory_ifc.cbus_ifc.write(11, unpack(2));
        enable_getB <= True;
    endrule

    rule getB_from_memory if( (enable_getB) && (enableAB==1) && 
                              (memory_ifc.device_ifc.modr_ready) );
    	let b_value <- memory_ifc.device_ifc.modr();
    	vector_inner.put_b(unpack(b_value));
    	enable_getB <= False;
    	enableAB <= 0;

        if(vector_size.Valid==1) 
    	begin
            vector_inner.end_value(True);
            vector_size <= tagged Invalid;
            addressA <= tagged Invalid;
            addressB <= tagged Invalid;
            csr_vector.o <= 2;
    	end

    	else 
    	begin
    		vector_inner.end_value(False);
            vector_size <= tagged Valid(vector_size.Valid - 1);
            addressA <= tagged Valid(addressA.Valid + 1);
            addressB <= tagged Valid(addressB.Valid + 1);
        end
    endrule


    //Stage 2

    //Here we wait for the inner module to give the final value and once we get it we immediately pass it to the memory to store it in the destination address. We store the value for displaying purposes.

    rule get_result if( (csr_vector.o==unpack(2)) && (vector_inner.final_done()) );
    	let value <- vector_inner.dot_result();
        memory_ifc.device_ifc.midr(pack(value));
        memory_ifc.device_ifc.mar(destination_address.Valid);
        memory_ifc.cbus_ifc.write(11, unpack(3));

        dot_value <= value;
        csr_vector.o <= 3;      //This is done for the purpose of displaying the result
    endrule


	//Rules to display the input vectors and the resulting product. Values are displayed row-wise. To display floating point values comment the rules used to display integer values and uncomment the rules used to display floating point values.
    Reg#(Bit#(Addr_size)) address1 <- mkReg(0);
    Reg#(Bit#(Addr_size)) address2 <- mkReg(0);
    Reg#(Bit#(Addr_size)) dest_address <- mkReg(0);
    Reg#(int) input_size <- mkReg(0);
    Reg#(Bit#(2)) display_stage <- mkReg(0);
    Reg#(int) vector_pos <- mkReg(0);
    Reg#(Bool) enable_retrieve <- mkReg(False);

    ////To display integer values.
    rule get_addresses if( (csr_vector.o==unpack(1)) && (display_stage==0) );
        address1 <= addressA.Valid;
        address2 <= addressB.Valid;
        dest_address <= destination_address.Valid;
        input_size <= vector_size.Valid;

        display_stage <= 1;
    endrule

    rule accessing_memoryA if( (csr_vector.o==unpack(3)) && (display_stage==1) && (!enable_retrieve) );
        memory_ifc.device_ifc.mar(address1);
        memory_ifc.cbus_ifc.write(11, unpack(2));

        enable_retrieve <= True;
    endrule

    rule retreiving_from_memoryA if( (display_stage==1) && (enable_retrieve) && (memory_ifc.device_ifc.modr_ready()) );
        let a_value <- memory_ifc.device_ifc.modr();
        $display("a[%d] = %d", ( vector_pos+1 ), a_value);
        enable_retrieve <= False;

        if(vector_pos==input_size-1)
        begin
            display_stage <= 2;
            $display("\n");
            vector_pos <= 0;
        end

        else
        begin
            address1 <= address1+1;
            vector_pos <= vector_pos+1;
        end
    endrule

    rule accessing_memoryB if( (display_stage==2) && (!enable_retrieve) );
        memory_ifc.device_ifc.mar(address2);
        memory_ifc.cbus_ifc.write(11, unpack(2));

        enable_retrieve <= True;
    endrule

    rule retreiving_from_memoryB if( (csr_vector.o==unpack(3)) && (display_stage==2) && (enable_retrieve) && (memory_ifc.device_ifc.modr_ready()) );
        let b_value <- memory_ifc.device_ifc.modr();
        $display("b[%d] = %d", ( vector_pos+1 ), b_value);
        enable_retrieve <= False;

        if(vector_pos==input_size-1)
        begin
            display_stage <= 3;
            $display("\n");
        end

        else
        begin
            address2 <= address2+1;
            vector_pos <= vector_pos+1;
        end
    endrule

    rule accessing_memoryR if( (display_stage==3) && (!enable_retrieve) );
        memory_ifc.device_ifc.mar(dest_address);
        memory_ifc.cbus_ifc.write(11, unpack(2));

        enable_retrieve <= True;
    endrule

    rule retreiving_from_memoryR if( (display_stage==3) && (enable_retrieve) && (memory_ifc.device_ifc.modr_ready()) );
        let r_value <- memory_ifc.device_ifc.modr();
        $display("Dot product = %d", r_value);
        $finish;
    endrule
    ////

    /* 
    ////To display floating point values
    rule get_addresses if( (csr_vector.o==unpack(1)) && (display_stage==0) );
        address1 <= addressA.Valid;
        address2 <= addressB.Valid;
        dest_address <= destination_address.Valid;
        input_size <= vector_size.Valid;

        display_stage <= 1;
    endrule

    rule accessing_memoryA if( (csr_vector.o==unpack(3)) && (display_stage==1) && (!enable_retrieve) );
        memory_ifc.device_ifc.mar(address1);
        memory_ifc.cbus_ifc.write(11, unpack(2));

        enable_retrieve <= True;
    endrule

    rule retreiving_from_memoryA if( (display_stage==1) && (enable_retrieve) && (memory_ifc.device_ifc.modr_ready()) );
        let a_value <- memory_ifc.device_ifc.modr();
        $display("a[%d] = ", ( vector_pos+1 ), fshow(a_value));
        enable_retrieve <= False;

        if(vector_pos==input_size-1)
        begin
            display_stage <= 2;
            $display("\n");
            vector_pos <= 0;
        end

        else
        begin
            address1 <= address1+1;
            vector_pos <= vector_pos+1;
        end
    endrule

    rule accessing_memoryB if( (display_stage==2) && (!enable_retrieve) );
        memory_ifc.device_ifc.mar(address2);
        memory_ifc.cbus_ifc.write(11, unpack(2));

        enable_retrieve <= True;
    endrule

    rule retreiving_from_memoryB if( (csr_vector.o==unpack(3)) && (display_stage==2) && (enable_retrieve) && (memory_ifc.device_ifc.modr_ready()) );
        let b_value <- memory_ifc.device_ifc.modr();
        $display("b[%d] = ", ( vector_pos+1 ), fshow(b_value));
        enable_retrieve <= False;

        if(vector_pos==input_size-1)
        begin
            display_stage <= 3;
            $display("\n");
        end

        else
        begin
            address2 <= address2+1;
            vector_pos <= vector_pos+1;
        end
    endrule

    rule accessing_memoryR if( (display_stage==3) && (!enable_retrieve) );
        memory_ifc.device_ifc.mar(dest_address);
        memory_ifc.cbus_ifc.write(11, unpack(2));

        enable_retrieve <= True;
    endrule

    rule retreiving_from_memoryR if( (display_stage==3) && (enable_retrieve) && (memory_ifc.device_ifc.modr_ready()) );
        let r_value <- memory_ifc.device_ifc.modr();
        $display("Dot product = ", fshow(r_value));
        $finish;
    endrule
    ////
    */

    method Action put_addressA (Bit#(Addr_size) addr1);
        addressA <= tagged Valid(addr1);
    endmethod
    method Action put_addressB (Bit#(Addr_size) addr2);
        addressB <= tagged Valid(addr2);
    endmethod    
    method Action size_of_vector (int v);
        vector_size <= tagged Valid(v);
    endmethod
    method Action put_destination_address (Bit#(Addr_size) dest);
        destination_address <= tagged Valid(dest);
    endmethod
endmodule
/////////////////////////////////////////////////////////////



//////Inner Module for Vector Multiplication////////////////

// This is the inner module which performs the vector dot multiplication in a pipelined manner. The module has three input ports and two output ports.
// Two input ports get each element of the vectors and the third input port tells the module if the input values is the last of the vector. 
// "accum_sum" register stores the accumulated sum of the products of past inputs and when the flag becomes true then the sum is passed to the output port. 
// Boolean True is also passed and can be used as an indicator for output using the method "final_done".


interface Vector_Inner_ifc#(type t);
    method Action put_a (t input1);     //Method to put the value of an element of the first vector.
    method Action put_b (t input2);     //Method to put the value of an element of the second vector.
    method Action end_value (Bool d_a); //Method to pass the flag to indicate if the inputs passed are the last
    method ActionValue#(t) dot_result;  //The final result can be received from here and is enabled only when the output is ready
    method Bool final_done;             //Method to check if output is ready
endinterface

(* synthesize *)
module mkVector_Inner(Vector_Inner_ifc#(M_type));
    
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

            a <= tagged Invalid;        //This is done so that the next stage doesn't get junk or repeated values
            b <= tagged Invalid;        //This also means that the values need not be passed continously

        end

        else
        begin
            prod <= tagged Invalid;
            flag_stage2 <= True;    //Reset value is being given to flag_stage2
        end
    endrule


    //Stage 2
    rule stage2_accumulated_sum ( isValid(prod) );
        final_result <= accum_sum + prod.Valid;

        if( flag_stage2 ) 
        begin
            done <= True;
            accum_sum <= 0;     //Reset is being given to accum_sum
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

endpackage