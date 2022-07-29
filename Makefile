bsc:
	@echo "This Makefile creates bsc folder and installs BlueSpec Compiler inside it"
	sudo apt-get install ghc libghc-regex-compat-dev libghc-syb-dev \
  libghc-old-time-dev libfontconfig1-dev libx11-dev libxft-dev flex bison \
  tcl-dev tk-dev libfontconfig1-dev libx11-dev libxft-dev gperf iverilog \
  libghc-split-dev
	sudo apt install autoconf
	sudo apt-get install itcl3-dev itk3-dev
	git clone --recursive https://github.com/B-Lang-org/bsc
	cd bsc && make PREFIX=$(pwd)
	cd bsc && make install-src
	export PATH=$(pwd)/bsc/inst/bin:$PATH
	bsc -help
	@echo "tested bsc using >> bsc -help"
	@echo "adding commandline to bashscript"
	sudo echo "export PATH=$(pwd)/bsc/inst/bin:\$PATH" >> ~/.bashrc

min:
	@echo "This Makefile creates bsc folder and installs BlueSpec Compiler inside it"
	sudo apt-get install ghc libghc-regex-compat-dev libghc-syb-dev \
  libghc-old-time-dev libfontconfig1-dev libx11-dev libxft-dev flex bison \
  tcl-dev tk-dev libfontconfig1-dev libx11-dev libxft-dev gperf iverilog \
  libghc-split-dev
	sudo apt install autoconf
	sudo apt-get install itcl3-dev itk3-dev
	git clone --recursive https://github.com/B-Lang-org/bsc
	cd bsc && make PREFIX=$(pwd)
	cd bsc && make install-src
	export PATH=$(pwd)/bsc/inst/bin:$PATH
	bsc -help
	@echo "tested bsc using >> bsc -help"
	
src-docs:
	@echo "This is to be done inside bsc folder"
	make install-doc
	@echo "If you get errors in the previous it is likely because you don't have tex installed"
