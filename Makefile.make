bsc:
	@echo "This Makefile creates bsc folder and installs bsc inside it"
	sudo apt-get install ghc libghc-regex-compat-dev libghc-syb-dev \
  libghc-old-time-dev libfontconfig1-dev libx11-dev libxft-dev flex bison \
  tcl-dev tk-dev libfontconfig1-dev libx11-dev libxft-dev gperf iverilog \
  libghc-split-dev
	sudo apt install autoconf
	sudo apt-get install itcl3-dev itk3-dev
	git clone --recursive https://github.com/B-Lang-org/bsc
	cd bsc && make PREFIX=$(pwd)
	cd bsc && make install-src
	cd bsc && make install-doc
	@echo "If you get errors in the previous it is likely because you don't have tex installed"
	export PATH=$(pwd)/bsc/inst/bin:$PATH
	bsc -help
	@echo "tested bsc using >> bsc -help"
	@echo "adding commandline to bashscript"
	sudo echo "export PATH=$(pwd)/inst/bin:\$PATH" >> ~/.bashrc
