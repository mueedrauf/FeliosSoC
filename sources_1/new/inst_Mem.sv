`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////////
//// Company: 
//// Engineer: 
//// 
//// Create Date: 06/16/2026 02:49:12 PM
//// Design Name: 
//// Module Name: inst_Mem
//// Project Name: 
//// Target Devices: 
//// Tool Versions: 
//// Description: 
//// 
//// Dependencies: 
//// 
//// Revision:
//// Revision 0.01 - File Created
//// Additional Comments:
//// 
////////////////////////////////////////////////////////////////////////////////////

module inst_Mem( 
    input logic [31:0] PC,
    output logic [31:0] Instr
    );
    
    // Expanded to 64 bytes to prevent out-of-bounds array access 
    // when indexing PC+3 near the end of the file.
    logic [7:0] instFile [63:0]; 
    
    initial begin
        // Initialize memory with 0s first to ensure unmapped spaces are clean
        for (integer i = 0; i < 64; i = i + 1) begin
            instFile[i] = 8'h00;
        end

        // Reads hex bytes from a file. 
        // Update the path "instructions.txt" to match your file's location.
        $readmemh("C:/Users/Mueed/Desktop/RV32I_SoC/RV32I_SoC.srcs/sources_1/new/instructions.txt", instFile);
    end
	
    // Little-Endian assembly: instFile[PC] is the lowest byte (bits 7:0)
    assign Instr = {instFile[PC+3], instFile[PC+2], instFile[PC+1], instFile[PC]};

endmodule

//module inst_Mem( 
//    input logic [31:0] PC,
//    output logic [31:0] Instr
//    );
    
//    logic [7:0] instFile [31:0];
    
    
//    // loops are not synthesizable in Verilog, this just define the file with 0's.   
//    integer i;
//	initial begin

//        // Instruction 2: add x6, x8, x9
//        instFile[0]  = 8'h33;
//        instFile[1]  = 8'h03;
//        instFile[2] = 8'h94;
//        instFile[3] = 8'h00;
        
        
//        // Instruction 3: sub x7, x6, x20
//        instFile[4] = 8'hB3;
//        instFile[5] = 8'h03;
//        instFile[6] = 8'h43;
//        instFile[7] = 8'h41;
        
//        // Instruction 0: lw x28, 4(x0)
//        instFile[8] = 8'h03;
//        instFile[9] = 8'h2E;
//        instFile[10] = 8'h40;
//        instFile[11] = 8'h00;
        

//        // Instruction 1: sw x7, 5(x6)
//        instFile[12] = 8'hA3;
//        instFile[13] = 8'h32;
//        instFile[14] = 8'h73;
//        instFile[15] = 8'h00;

	    
//	    // Instruction 8: beq x29 x29 label
//	    instFile[16] = 8'h63;
//	    instFile[17] = 8'h82;
//	    instFile[18] = 8'hDE;
//	    instFile[19] = 8'h01;
	    
//	    // all are add
//	    instFile[20] = 8'h0;
//	    instFile[21] = 8'h0;
//	    instFile[22] = 8'h0;
//	    instFile[23] = 8'h0;
	    
//	    // jump instruction
//	    instFile[24] = 8'hef;
//	    instFile[25] = 8'hf0;
//	    instFile[26] = 8'h9f;
//	    instFile[27] = 8'hff;
	    
	    
//	    instFile[28] = 8'h33;
//	    instFile[29] = 8'h00;
//	    instFile[30] = 8'h94;
//	    instFile[31] = 8'h00;
	    

	    
	    
//	end
	
//	assign Instr = {instFile[PC+3], instFile[PC+2], instFile[PC+1], instFile[PC] };

//endmodule
