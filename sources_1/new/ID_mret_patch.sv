`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/23/2026 04:02:47 PM
// Design Name: 
// Module Name: ID
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module ID (
    input  logic        clk,
    input  logic        rst,
    input  logic        WBStall,
    input  logic        FlushE,

    input  logic [31:0] InstrD,
    input  logic [31:0] PCD,
    input  logic [31:0] PCPlus4D,

    // Write-back bus
    input  logic        RegWriteW,
    input  logic [4:0]  RDW,
    input  logic [31:0] ResultW,

    // Outputs to EX stage
    output logic        RegWriteE,
    output logic        MemWriteE,
    output logic        JumpE,
    output logic        BranchE,
    output logic        ALUSrcE,
    output logic [1:0]  ResultSrcE,
    output logic [2:0]  ALUControlE,
    output logic [31:0] RD1E,
    output logic [31:0] RD2E,
    output logic [31:0] PCE,
    output logic [4:0]  RdE,
    output logic [31:0] ImmExtE,
    output logic [31:0] PCPlus4E,
    output logic [4:0]  Rs1E,
    output logic [4:0]  Rs2E,
    output logic [4:0]  Rs1D,
    output logic [4:0]  Rs2D,

    // NEW: mret detection 
    output logic        MRetE
);


    logic [4:0] rs1, rs2, rd;
    logic [6:0] opcode;
    logic [2:0] func3;
    logic [6:0] func7;
    logic [11:0] imm;
    logic [19:0] imm_j;     // wire for jump imm field
    logic       RegWrite;
    logic [1:0] ImmSrc;
    logic       ALUSrc;
    logic       MemWrite;
    logic [1:0] ResultSrc;
    logic       Branch;    // same as pc source
    logic [1:0] ALUOp;
    logic [2:0] ALUControl;
    logic jump;
    //////////// wire for reg file
    
    logic [31:0] readData1, readData2;
   
    //////////// wire for sign extension
    
    logic [31:0] ImmExt;    //output of sign extension
 
    
    ///////// Decoder 
    
    // mret detection
    logic MRetD;
    assign MRetD = (InstrD == 32'h3020_0073);

    //  Register MRetD → MRetE  (flush on FlushE or rst) 
    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            MRetE <= 1'b0;
        else if (!WBStall) begin
            if (FlushE)
                MRetE <= 1'b0;
            else
                MRetE <= MRetD;
        end
    end

    
    assign Rs1D = rs1;
    assign Rs2D = rs2;
    
    
    always_ff @(posedge clk or posedge rst) begin

    if (rst) begin

        RegWriteE  <= 0;
        MemWriteE  <= 0;
        JumpE      <= 0;
        BranchE    <= 0;
        ALUSrcE    <= 0;
        ResultSrcE <= 0;
        ALUControlE<= 0;
        RD1E       <= 0;
        RD2E       <= 0;
        PCE        <= 0;
        RdE        <= 0;
        ImmExtE    <= 0;
        PCPlus4E   <= 0;
        Rs1E       <= 0;
        Rs2E       <= 0;

    end
    else if (!WBStall) begin

        if (FlushE) begin

            RegWriteE  <= 0;
            MemWriteE  <= 0;
            JumpE      <= 0;
            BranchE    <= 0;
            ALUSrcE    <= 0;
            ResultSrcE <= 0;
            ALUControlE<= 0;
            RD1E       <= 0;
            RD2E       <= 0;
            PCE        <= 0;
            RdE        <= 0;
            ImmExtE    <= 0;
            PCPlus4E   <= 0;
            Rs1E       <= 0;
            Rs2E       <= 0;

        end
        else begin

            RegWriteE   <= RegWrite;
            MemWriteE   <= MemWrite;
            JumpE       <= jump;
            BranchE     <= Branch;
            ALUSrcE     <= ALUSrc;
            ResultSrcE  <= ResultSrc;
            ALUControlE <= ALUControl;
            RD1E        <= readData1;
            RD2E        <= readData2;
            PCE         <= PCD;
            RdE         <= rd;
            ImmExtE     <= ImmExt;
            PCPlus4E    <= PCPlus4D;
            Rs1E        <= rs1;
            Rs2E        <= rs2;

        end

    end

end
    
     Decoder p5(
    .Instr(InstrD),
    .rs1(rs1), .rs2(rs2), .rd(rd),
    .opcode(opcode),
    .func3(func3), 
    .func7(func7),
    .imm(imm),
    .imm_j(imm_j)
    );      
    
    Control_Unit p6(
    .Op(opcode),
    .RegWrite(RegWrite),
    .ImmSrc(ImmSrc),
    .ALUSrc(ALUSrc),
    .MemWrite(MemWrite),
    .ResultSrc(ResultSrc),
    .Branch(Branch),
    .jump(jump),
    .ALUOp(ALUOp)
    );
    
    Reg_file p7( 
    .clk(clk),
    .rst(rst),
    .RegWrite(RegWriteW),
    .readReg1(rs1), .readReg2(rs2), .writeReg(RDW),
    .writeData(ResultW),
    .readData1(readData1),
    .readData2(readData2)
    );   
    
    sign_extender p8(
    .ImmSrc(ImmSrc),
    .imm(imm),
    .imm_j(imm_j),
    .ImmExt(ImmExt)
    );

    ALU_decoder p9 (
    .ALUOp(ALUOp),
    .func3(func3),
    .func7_5(func7[5]),
    .op5(opcode[5]),
    .ALUControl(ALUControl)
    );

endmodule
