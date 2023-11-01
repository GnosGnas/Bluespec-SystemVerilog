## Replace with your path
BSC_DIR := /home/surya/BLUESPEC/bsc

all: compile_bsv verilog_bsc

## Standard compilation is only required
compile_bsv:
	bsc -verilog Wrapper.bsv

## Here mymac.v need not be specified but if there are other modules which are needed by mymac.v then specify them along with mkTb.v
verilog_bsc:
	bsc -o out -e mkTb mkTb.v
	./out 

verilog_iverilog:
	iverilog -DTOP=mkTb $(BSC_DIR)/src/Verilog/main.v mkTb.v mymac.v -o out 
	./out

clean:
	rm *.bo mkTb.v