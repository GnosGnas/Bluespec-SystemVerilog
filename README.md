# Bluespec SystemVerilog
## Hardware Designing using Bluespec SystemVerilog

To install BlueSpec compiler download the makefile and run make. Please note that it will add the path to the bashrc file so that you don't have to export the PATH variable everytime. If you don't want that run make min. (last updated - Feb '22)  

Matrix Multiplication project - The files are executed using bsc compiler and the commands to be entered in terminal have been provided in the project report
Systolic arrays - The directory contains codes for Systolic Matrix Multiplier and Systolic Vector Dot. Systolic arrays are a great design to efficiently feed elements part by part and also get the output in parts. This allows less usage of memory and it also uses less resources due to its structure.

Inv DCT - BSV code for inverse discrete cosine transform. This code has been fully pipelined and a user can simply change the define variables on the top of the bsv code to choose the number of pipeline stages. Details about the architecture can be found in the pdf file in the directory
