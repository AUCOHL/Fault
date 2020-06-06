////////////////////////////////////////////////////////////////////////////////
//
//  Copyright 2008-2013 by Michael A. Morris, dba M. A. Morris & Associates
//
//  All rights reserved. The source code contained herein is publicly released
//  under the terms and conditions of the GNU Lesser Public License. No part of
//  this source code may be reproduced or transmitted in any form or by any
//  means, electronic or mechanical, including photocopying, recording, or any
//  information storage and retrieval system in violation of the license under
//  which the source code is released.
//
//  The source code contained herein is free; it may be redistributed and/or
//  modified in accordance with the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either version 2.1 of
//  the GNU Lesser General Public License, or any later version.
//
//  The source code contained herein is freely released WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
//  PARTICULAR PURPOSE. (Refer to the GNU Lesser General Public License for
//  more details.)
//
//  A copy of the GNU Lesser General Public License should have been received
//  along with the source code contained herein; if not, a copy can be obtained
//  by writing to:
//
//  Free Software Foundation, Inc.
//  51 Franklin Street, Fifth Floor
//  Boston, MA  02110-1301 USA
//
//  Further, no use of this source code is permitted in any form or means
//  without inclusion of this banner prominently in any derived works.
//
//  Michael A. Morris
//  Huntsville, AL
//
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company:         M. A. Morris & Associates
// Engineer:        Michael A. Morris
//
// Create Date:     11:30:15 01/13/2008
// Design Name:     PIC16C5x
// Module Name:     C:/ISEProjects/ISE10.1i/P16C5x/PIC16C5x_Top.v
// Project Name:    PIC16C5x
// Target Devices:  N/A
// Tool versions:   ISEWebPACK 10.1i SP3
//
// Description: Module implements a pipelined PIC16C5x processor. The processor
//              implements all PIC16C5x instructions and the normal peripherals
//
//
// Dependencies:    None
//
// Revision:
//
//  0.00    08A13   MAM     File Created
//
//  0.01    08B14   MAM     Initial Completion. Fully Built
//
//  0.02    08B17   MAM     Moved Skip logic to system level and included the
//                          GOTO, CALL, and RETLW instructions in the skip
//                          logic equations. Inserted change to decoded ALU_Op
//                          that routes the KI register through the ALU with a
//                          NOP configuration so that the PCL writes and CALL
//                          correctly load the PC.
//
//  0.03    08B24   MAM     Modified Input Port List: CE => ClkEn. Modification
//                          made in order to implement the SLEEP instruction.
//                          SLEEP sets the PD bit in STATUS, and stops the
//                          execution of processor. Only an external reset or
//                          a Watchdog Timer Timeout will restart execution of
//                          the processor through the reset vector location.
//
//  0.04    08B27   MAM     Modified the SKIP signal to include the SLEEP in-
//                          struction. Modified the PD and TO FFs to accept
//                          WE_WDTCLR as the reset signal. This moves up the
//                          clearing of the TO and PD FFs by one clock cyle,
//                          which means that the CLRWDT; BTFSx STATUS,{TO | PD}
//                          instruction sequence will execute correctly. Before
//                          this change, that instruction sequence would not
//                          detect the change in either of these two FFs be-
//                          cause the synchronous reset action was not being
//                          effected before the test during the execution phase
//                          of the BTFSx instruction.
//
//  0.05    08B28   MAM     Added multiplexer to STATUS bits, Z, DC, and C, so
//                          file register write instructions that don't modify
//                          these bits (Table 10-2: Instruction Set Summary)
//                          will write the File Register bus into these bits.
//                          The DECFSZ and INCFSZ instructions are excluded in
//                          this list; theyshould never be directed to use
//                          STATUS since it might result in a non-terminating
//                          loop. To include these two instructions, remove
//                          ALU_Op[8], Test, from the write enable equation.
//
//  0.06    08B28   MAM     Added load function to TMR0.
//
//  0.99    08B28   MAM     Reset WDT_Size parameter to 20 bits. Need to reduce
//                          size to reasonable value for simulation.
//
//  1.00    08B28   MAM     Initial Release
//
//  1.01    08B29   MAM     Added WE_PCL to Skip in order to implement the com-
//                          puted GOTO functionality which occurs when File
//                          register writes occur to the PCL Special Function
//                          Register address. The change in the execution
//                          sequence which occurs requires that the instruction
//                          pipeline be flushed while the new destination
//                          is being fetched and decoded.
//
//  1.02    13B10   MAM     Converted to Verilog-2001
//
//  1.10    13G20   MAM     Corrected error in BTFSC/BTFSS not detected by the
//                          test bench. Skip logic qualifier for bit test signal
//                          using wrong two bits of ALU_Op[1:0] instead of
//                          ALU_Op[7:6]. Correction made. Additional tests not
//                          added to testbench at this time.
//
// Additional Comments:
//
////////////////////////////////////////////////////////////////////////////////

module PIC16C5x #(
    parameter WDT_Size = 20     // Use 20 for synthesis, Use 10 for Simulation
)(
    input   POR,                // In  - System Power-On Reset

    input   Clk,                // In  - System Clock
    input   ClkEn,              // In  - Processor Clock Enable

    output  reg [11:0] PC,      // Out - Program Counter
    input   [11:0] IR,          // In  - Instruction Register

    output  reg [3:0] TRISA,    // Out - Port A Tri-state Control Register
    output  reg [3:0] PORTA,    // Out - Port A Data Register
    input   [3:0] PA_DI,        // In  - Port A Input Pins

    output  reg [7:0] TRISB,    // Out - Port B Tri-state Control Register
    output  reg [7:0] PORTB,    // Out - Port B Data Register
    input   [7:0] PB_DI,        // In  - Port B Input Pins

    output  reg [7:0] TRISC,    // Out - Port C Tri-state Control Register
    output  reg [7:0] PORTC,    // Out - Port C Data Register
    input   [7:0] PC_DI,        // In  - Port C Input Pins

    input   MCLR,               // In  - Master Clear Input
    input   T0CKI,              // In  - Timer 0 Clock Input

    input   WDTE,               // In  - Watchdog Timer Enable
//
//  Debug Outputs
//
    output  reg Err,            // Out - Instruction Decode Error Output

    output  reg [5:0] OPTION,   // Out - Processor Configuration Register Output

    output  reg [ 8:0] dIR,     // Out - Pipeline Register (Non-ALU Instruct.)
    output  reg [11:0] ALU_Op,  // Out - Pipeline Register (ALU Instructions)
    output  reg [ 8:0] KI,      // Out - Pipeline Register (Literal)
    output  reg Skip,           // Out - Skip Next Instruction

    output  reg [11:0] TOS,     // Out - Top-Of-Stack Register Output
    output  reg [11:0] NOS,     // Out - Next-On-Stack Register Output

    output  reg [7:0] W,        // Out - Working Register Output

    output  [6:0] FA,           // Out - File Address Output
    output  reg [7:0] DO,       // Out - File Data Input/ALU Data Output
    output  [7:0] DI,           // Out - File Data Output/ALU Data Input

    output  reg [7:0] TMR0,     // Out - Timer 0 Timer/Counter Output
    output  reg [7:0] FSR,      // Out - File Select Register Output
    output  [7:0] STATUS,       // Out - Processor Status Register Output

    output  T0CKI_Pls,          // Out - Timer 0 Clock Edge Pulse Output

    output  reg WDTClr,         // Out - Watchdog Timer Clear Output
    output  reg [WDT_Size-1:0] WDT, // Out - Watchdog Timer
    output  reg WDT_TC,
    output  WDT_TO,             // Out - Watchdog Timer Timeout Output

    output  reg [7:0] PSCntr,   // Out - Prescaler Counter Output
    output  PSC_Pls             // Out - Prescaler Count Pulse Output
);

////////////////////////////////////////////////////////////////////////////////
//
//  Local Parameter Declarations
//
//  Unused Opcodes - PIC16C5x Family
//
//localparam OP_RSVD01 = 12'b0000_0000_0001;   // Reserved - Unused Opcode
//
//localparam OP_RSVD08 = 12'b0000_0000_1000;   // Reserved - Unused Opcode
//localparam OP_RSVD09 = 12'b0000_0000_1001;   // Reserved - Unused Opcode
//localparam OP_RSVD10 = 12'b0000_0000_1010;   // Reserved - Unused Opcode
//localparam OP_RSVD11 = 12'b0000_0000_1011;   // Reserved - Unused Opcode
//localparam OP_RSVD12 = 12'b0000_0000_1100;   // Reserved - Unused Opcode
//localparam OP_RSVD13 = 12'b0000_0000_1101;   // Reserved - Unused Opcode
//localparam OP_RSVD14 = 12'b0000_0000_1110;   // Reserved - Unused Opcode
//localparam OP_RSVD15 = 12'b0000_0000_1111;   // Reserved - Unused Opcode
//localparam OP_RSVD16 = 12'b0000_0001_0000;   // Reserved - Unused Opcode
//localparam OP_RSVD17 = 12'b0000_0001_0001;   // Reserved - Unused Opcode
//localparam OP_RSVD18 = 12'b0000_0001_0010;   // Reserved - Unused Opcode
//localparam OP_RSVD19 = 12'b0000_0001_0011;   // Reserved - Unused Opcode
//localparam OP_RSVD20 = 12'b0000_0001_0100;   // Reserved - Unused Opcode
//localparam OP_RSVD21 = 12'b0000_0001_0101;   // Reserved - Unused Opcode
//localparam OP_RSVD22 = 12'b0000_0001_0110;   // Reserved - Unused Opcode
//localparam OP_RSVD23 = 12'b0000_0001_0111;   // Reserved - Unused Opcode
//localparam OP_RSVD24 = 12'b0000_0001_1000;   // Reserved - Unused Opcode
//localparam OP_RSVD25 = 12'b0000_0001_1001;   // Reserved - Unused Opcode
//localparam OP_RSVD26 = 12'b0000_0001_1010;   // Reserved - Unused Opcode
//localparam OP_RSVD27 = 12'b0000_0001_1011;   // Reserved - Unused Opcode
//localparam OP_RSVD28 = 12'b0000_0001_1100;   // Reserved - Unused Opcode
//localparam OP_RSVD29 = 12'b0000_0001_1101;   // Reserved - Unused Opcode
//localparam OP_RSVD30 = 12'b0000_0001_1110;   // Reserved - Unused Opcode
//localparam OP_RSVD31 = 12'b0000_0001_1111;   // Reserved - Unused Opcode
//
//localparam OP_RSVD65 = 12'b0000_0100_0001;   // Reserved - Unused Opcode
//localparam OP_RSVD66 = 12'b0000_0100_0010;   // Reserved - Unused Opcode
//localparam OP_RSVD67 = 12'b0000_0100_0011;   // Reserved - Unused Opcode
//localparam OP_RSVD68 = 12'b0000_0100_0100;   // Reserved - Unused Opcode
//localparam OP_RSVD69 = 12'b0000_0100_0101;   // Reserved - Unused Opcode
//localparam OP_RSVD70 = 12'b0000_0100_0110;   // Reserved - Unused Opcode
//localparam OP_RSVD71 = 12'b0000_0100_0111;   // Reserved - Unused Opcode
//localparam OP_RSVD72 = 12'b0000_0100_1000;   // Reserved - Unused Opcode
//localparam OP_RSVD73 = 12'b0000_0100_1001;   // Reserved - Unused Opcode
//localparam OP_RSVD74 = 12'b0000_0100_1010;   // Reserved - Unused Opcode
//localparam OP_RSVD75 = 12'b0000_0100_1011;   // Reserved - Unused Opcode
//localparam OP_RSVD76 = 12'b0000_0100_1100;   // Reserved - Unused Opcode
//localparam OP_RSVD77 = 12'b0000_0100_1101;   // Reserved - Unused Opcode
//localparam OP_RSVD78 = 12'b0000_0100_1110;   // Reserved - Unused Opcode
//localparam OP_RSVD79 = 12'b0000_0100_1111;   // Reserved - Unused Opcode
//localparam OP_RSVD80 = 12'b0000_0101_0000;   // Reserved - Unused Opcode
//localparam OP_RSVD81 = 12'b0000_0101_0001;   // Reserved - Unused Opcode
//localparam OP_RSVD82 = 12'b0000_0101_0010;   // Reserved - Unused Opcode
//localparam OP_RSVD83 = 12'b0000_0101_0011;   // Reserved - Unused Opcode
//localparam OP_RSVD84 = 12'b0000_0101_0100;   // Reserved - Unused Opcode
//localparam OP_RSVD85 = 12'b0000_0101_0101;   // Reserved - Unused Opcode
//localparam OP_RSVD86 = 12'b0000_0101_0110;   // Reserved - Unused Opcode
//localparam OP_RSVD87 = 12'b0000_0101_0111;   // Reserved - Unused Opcode
//localparam OP_RSVD88 = 12'b0000_0101_1000;   // Reserved - Unused Opcode
//localparam OP_RSVD89 = 12'b0000_0101_1001;   // Reserved - Unused Opcode
//localparam OP_RSVD90 = 12'b0000_0101_1010;   // Reserved - Unused Opcode
//localparam OP_RSVD91 = 12'b0000_0101_1011;   // Reserved - Unused Opcode
//localparam OP_RSVD92 = 12'b0000_0101_1100;   // Reserved - Unused Opcode
//localparam OP_RSVD93 = 12'b0000_0101_1101;   // Reserved - Unused Opcode
//localparam OP_RSVD94 = 12'b0000_0101_1110;   // Reserved - Unused Opcode
//localparam OP_RSVD95 = 12'b0000_0101_1111;   // Reserved - Unused Opcode
//
////////////////////////////////////////////////////////////////////////////////
//
//  PIC16C5x Family Opcodes

localparam OP_NOP    = 12'b0000_0000_0000;   // No Operation
localparam OP_OPTION = 12'b0000_0000_0010;   // Set Option Register
localparam OP_SLEEP  = 12'b0000_0000_0011;   // Set Sleep Register
localparam OP_CLRWDT = 12'b0000_0000_0100;   // Clear Watchdog Timer
localparam OP_TRISA  = 12'b0000_0000_0101;   // Set Port A Tristate Control Reg
localparam OP_TRISB  = 12'b0000_0000_0110;   // Set Port B Tristate Control Reg
localparam OP_TRISC  = 12'b0000_0000_0111;   // Set Port C Tristate Control Reg
localparam OP_MOVWF  =  7'b0000_001;         // F = W;
localparam OP_CLRW   = 12'b0000_0100_0000;   // W = 0; Z;
localparam OP_CLRF   =  7'b0000_011; // F = 0; Z;
localparam OP_SUBWF  =  6'b0000_10;  // D ? F = F - W : W = F - W; Z, C, DC;
localparam OP_DECF   =  6'b0000_11;  // D ? F = F - 1 : W = F - 1; Z;
//
localparam OP_IORWF  =  6'b0001_00;  // D ? F = F | W : W = F | W; Z;
localparam OP_ANDWF  =  6'b0001_01;  // D ? F = F & W : W = F & W; Z;
localparam OP_XORWF  =  6'b0001_10;  // D ? F = F ^ W : W = F ^ W; Z;
localparam OP_ADDWF  =  6'b0001_11;  // D ? F = F + W : W = F + W; Z, C, DC;
//
localparam OP_MOVF   =  6'b0010_00;  // D ? F = F     : W = F    ; Z;
localparam OP_COMF   =  6'b0010_01;  // D ? F = ~F    : W = ~F   ; Z;
localparam OP_INCF   =  6'b0010_10;  // D ? F = F + 1 : W = F + 1; Z;
localparam OP_DECFSZ =  6'b0010_11;  // D ? F = F - 1 : W = F - 1; skip if Z;
//
localparam OP_RRF    =  6'b0011_00;  // D ? F = {C,F[7:1]} : W={C,F[7:1]};C=F[0]
localparam OP_RLF    =  6'b0011_01;  // D ? F = {F[6:0],C} : W={F[6:0],C};C=F[7]
localparam OP_SWAPF  =  6'b0011_10;  // D ? F = t : W = t; t = {F[3:0], F[7:4]}
localparam OP_INCFSZ =  6'b0011_11;  // D ? F = F - 1 : W = F - 1; skip if Z;
//
localparam OP_BCF    =  4'b0100;     // F = F & ~(1 << bit);
localparam OP_BSF    =  4'b0101;     // F = F |  (1 << bit);
localparam OP_BTFSC  =  4'b0110;     // skip if F[bit] == 0;
localparam OP_BTFSS  =  4'b0111;     // skip if F[bit] == 1;
localparam OP_RETLW  =  4'b1000;     // W = L; Pop(PC = TOS);
localparam OP_CALL   =  4'b1001;     // Push(TOS=PC+1); PC={PA[2:0],0,L[7:0]};
localparam OP_GOTO   =  3'b101;      // PC = {PA[2:0], L[8:0]};
localparam OP_MOVLW  =  4'b1100;     // W = L[7:0];
localparam OP_IORLW  =  4'b1101;     // W = L[7:0] | W; Z;
localparam OP_ANDLW  =  4'b1110;     // W = L[7:0] & W; Z;
localparam OP_XORLW  =  4'b1111;     // W = L[7:0] ^ W; Z;

//  Special Function Register Addresses

localparam pINDF   = 5'b0_0000;
localparam pTMR0   = 5'b0_0001;
localparam pPCL    = 5'b0_0010;
localparam pSTATUS = 5'b0_0011;
localparam pFSR    = 5'b0_0100;
localparam pPORTA  = 5'b0_0101;
localparam pPORTB  = 5'b0_0110;
localparam pPORTC  = 5'b0_0111;

//
////////////////////////////////////////////////////////////////////////////////
//
//  Module Level Declarations
//

wire    Rst;                // Logical OR of POR, MClr and WDT_TO

wire    CE;                 // Internal Clock Enable: CE <= ClkEn & ~PD;

reg     [2:0] PA;           // PC Load Register PC[11:9] = PA[2:0]
reg     [7:0] SFR;          // Special Function Registers Data Output
reg     [7:0] XDO;          // Bank Switched RAM Block Data Output

wire    Rst_TO;             // Rst TO FF signal
reg     TO;                 // Time Out FF (STATUS Register)
wire    Rst_PD, Set_PD;     // Rst/Set PD FF signal
reg     PD;                 // Power Down FF (STATUS Register)
reg     PwrDn;              // Power Down FF

wire    [3:0] Addrs;        // RAM Address: FA[3:0]
reg     [7:0] RAMA[15:0];   // RAM Block 1 - 0x08 - 0x0F
reg     [7:0] RAMB[15:0];   // RAM Block 2 = 0x10 - 0x1F, FSR[6:5] = 2'b00
reg     [7:0] RAMC[15:0];   // RAM Block 2 = 0x10 - 0x1F, FSR[6:5] = 2'b01
reg     [7:0] RAMD[15:0];   // RAM Block 2 = 0x10 - 0x1F, FSR[6:5] = 2'b10
reg     [7:0] RAME[15:0];   // RAM Block 2 = 0x10 - 0x1F, FSR[6:5] = 2'b11

wire    T0CS;               // Timer 0 Clock Source Select
wire    T0SE;               // Timer 0 Source Edge
wire    PSA;                // Prescaler Assignment
wire    [2:0] PS;           // Prescaler Counter Output Bit Select

reg     [2:0] dT0CKI;       // Ext T0CKI Synchronized RE/RE FF chain
reg     PSC_Out;            // Synchronous Prescaler TC register
reg     [1:0] dPSC_Out;     // Rising Edge Detector for Prescaler output

wire    GOTO, CALL, RETLW;  // Signals for Decoded Instruction Register
wire    WE_SLEEP, WE_WDTCLR;
wire    WE_TRISA, WE_TRISB, WE_TRISC;
wire    WE_OPTION;

wire    WE_TMR0;            // Write Enable Signals Decoded from FA[4:0]
wire    WE_PCL;
wire    WE_STATUS;
wire    WE_FSR;
wire    WE_PORTA;
wire    WE_PORTB;
wire    WE_PORTC;

wire    WE_PSW;             // Write Enable for STATUS[2:0]: {Z, DC, C}

////////////////////////////////////////////////////////////////////////////////
//
//  Instruction Decoder Declarations
//

wire    dNOP, dOPTION, dSLEEP, dCLRWDT, dTRISA, dTRISB, dTRISC;
wire    dMOVWF, dCLRW, dCLRF, dSUBWF, dDECF;
wire    dIORWF, dANDWF, dXORWF, dADDWF;
wire    dMOVF, dCOMF, dINCF, dDECFSZ;
wire    dRRF, dRLF, dSWAPF, dINCFSZ;
wire    dBCF, dBSF, dBTFSC, dBTFSS;
wire    dRETLW, dCALL, dGOTO;
wire    dMOVLW, dIORLW, dANDLW, dXORLW;
wire    dErr;

wire    dAU_Op, dLU_Op, dSU_Op, dLW_Op, dBP_Op;
wire    dFile_En, dTst, dINDF, dWE_W, dWE_F;
wire    [11:0] dALU_Op;

////////////////////////////////////////////////////////////////////////////////
//
//  ALU Declarations
//

wire    [7:0] A, B;     // ALU Data Input Bus inputs:
                        //  A - external data: {DI | KI}
                        //  B - {W, ~W, 0x00, 0xFF}

reg     C, DC, Z;       // ALU Status Outputs

wire    A_Sel, B_Sel, B_Inv, C_In;
wire    [7:0] Y;
wire    [7:0] X;
wire    C_Out, C_Drv, DC_In;

wire    [1:0] LU_Op;
reg     [7:0] V;

wire    [2:0] Bit;
reg     [7:0] Msk;
wire    Set, Tst;
wire    [7:0] U, T;
wire    g;

wire    [1:0] S_Sel;
wire    S_Dir;
reg     [7:0] S;

wire    [1:0] D_Sel;

wire    C_Sel, DC_Sel, Z_Sel, Z_Tst;

wire    INDF, WE_W, WE_F;

//
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
//  Top Level Implementation
//

assign  Rst = POR | MCLR | WDT_TO;  // Internal Processor Reset
assign  CE  = ClkEn & ~PwrDn;       // Internal Clock Enable, refer to comments

//
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
//  Instruction Decoder Implementation
//

assign dNOP    = (OP_NOP    == IR[11:0]);
assign dOPTION = (OP_OPTION == IR[11:0]);
assign dSLEEP  = (OP_SLEEP  == IR[11:0]);
assign dCLRWDT = (OP_CLRWDT == IR[11:0]);
assign dTRISA  = (OP_TRISA  == IR[11:0]);
assign dTRISB  = (OP_TRISB  == IR[11:0]);
assign dTRISC  = (OP_TRISC  == IR[11:0]);
assign dMOVWF  = (OP_MOVWF  == IR[11:5]);
assign dCLRW   = (OP_CLRW   == IR[11:0]);
assign dCLRF   = (OP_CLRF   == IR[11:5]);
assign dSUBWF  = (OP_SUBWF  == IR[11:6]);
assign dDECF   = (OP_DECF   == IR[11:6]);
assign dIORWF  = (OP_IORWF  == IR[11:6]);
assign dANDWF  = (OP_ANDWF  == IR[11:6]);
assign dXORWF  = (OP_XORWF  == IR[11:6]);
assign dADDWF  = (OP_ADDWF  == IR[11:6]);
assign dMOVF   = (OP_MOVF   == IR[11:6]);
assign dCOMF   = (OP_COMF   == IR[11:6]);
assign dINCF   = (OP_INCF   == IR[11:6]);
assign dDECFSZ = (OP_DECFSZ == IR[11:6]);
assign dRRF    = (OP_RRF    == IR[11:6]);
assign dRLF    = (OP_RLF    == IR[11:6]);
assign dSWAPF  = (OP_SWAPF  == IR[11:6]);
assign dINCFSZ = (OP_INCFSZ == IR[11:6]);
assign dBCF    = (OP_BCF    == IR[11:8]);
assign dBSF    = (OP_BSF    == IR[11:8]);
assign dBTFSC  = (OP_BTFSC  == IR[11:8]);
assign dBTFSS  = (OP_BTFSS  == IR[11:8]);
assign dRETLW  = (OP_RETLW  == IR[11:8]);
assign dCALL   = (OP_CALL   == IR[11:8]);
assign dGOTO   = (OP_GOTO   == IR[11:9]);
assign dMOVLW  = (OP_MOVLW  == IR[11:8]);
assign dIORLW  = (OP_IORLW  == IR[11:8]);
assign dANDLW  = (OP_ANDLW  == IR[11:8]);
assign dXORLW  = (OP_XORLW  == IR[11:8]);

assign dErr    = ~|{dNOP,   dOPTION, dSLEEP, dCLRWDT, dTRISA, dTRISB, dTRISC,
                    dMOVWF, dCLRW,   dCLRF,  dSUBWF,  dDECF,
                    dIORWF, dANDWF,  dXORWF, dADDWF,
                    dMOVF,  dCOMF,   dINCF,  dDECFSZ,
                    dRRF,   dRLF,    dSWAPF, dINCFSZ,
                    dBCF,   dBSF,    dBTFSC, dBTFSS,
                    dRETLW, dCALL,   dGOTO,  dMOVLW,  dIORLW, dANDLW, dXORLW};

//  ALU Operation Decode

assign dAU_Op   = |{dSUBWF, dDECF, dADDWF, dMOVF, dINCF, dDECFSZ, dINCFSZ};
assign dLU_Op   = |{dCOMF, dIORWF, dANDWF, dXORWF};
assign dSU_Op   = |{dRRF, dRLF, dSWAPF};
assign dBP_Op   = |{dBCF, dBSF, dBTFSC, dBTFSS};
assign dLW_Op   = |{dCLRW,  dRETLW, dMOVLW, dIORLW, dANDLW, dXORLW};
assign dFile_En = |{dMOVWF, dCLRF,  dAU_Op, dLU_Op, dSU_Op, dBP_Op};
assign dINDF    = dFile_En & (IR[4:0] == pINDF);

assign dTst  = |{dDECFSZ, dINCFSZ, dBTFSC, dBTFSS};
assign dWE_F = |{dBP_Op, ((dAU_Op | dLU_Op | dSU_Op) &  IR[5]), dMOVWF, dCLRF};
assign dWE_W = |{dLW_Op, ((dAU_Op | dLU_Op | dSU_Op) & ~IR[5])};


assign dALU_Op[ 0] = (dBP_Op ? IR[5] : |{dSUBWF, dINCF, dINCFSZ,
                                         dIORLW, dXORLW,
                                         dIORWF, dXORWF,
                                         dRLF,   dSWAPF});
assign dALU_Op[ 1] = (dBP_Op ? IR[6] : |{dSUBWF, dDECF,  dDECFSZ,
                                         dANDWF, dXORWF, dANDLW,  dXORLW,
                                         dRRF,   dRLF});
assign dALU_Op[ 2] = (dBP_Op ? IR[7] : |{dSUBWF, dADDWF, dMOVWF,
                                         dIORWF, dANDWF, dXORWF,
                                         dIORLW, dANDLW, dXORLW});
assign dALU_Op[ 3] = |{dBSF, dBTFSS,   dCALL,  dRETLW,
                       dMOVLW, dIORLW, dANDLW, dXORLW};
assign dALU_Op[ 4] = |{dSUBWF, dADDWF, dRRF, dRLF};
assign dALU_Op[ 5] = |{dSUBWF, dDECF,  dADDWF, dINCF,  dMOVF,
                       dIORWF, dANDWF, dXORWF, dIORLW, dANDLW, dXORLW};
assign dALU_Op[ 6] = dBP_Op | dLU_Op | dIORLW | dANDLW | dXORLW;
assign dALU_Op[ 7] = dBP_Op | dSU_Op | dMOVWF | dCLRW  | dCLRF;
assign dALU_Op[ 8] = dTst;
assign dALU_Op[ 9] = dINDF;
assign dALU_Op[10] = dWE_W;
assign dALU_Op[11] = dWE_F;

//  Decoded Instruction Register

always @(posedge Clk)
begin
    if(Rst)
        dIR <= #1 9'b0_0000_0000;
    else if(CE)
        dIR <= #1 (Skip ? 9'b0_0000_0000
                        : {dOPTION,
                           dTRISC,  dTRISB, dTRISA,
                           dCLRWDT, dSLEEP,
                           dRETLW,  dCALL,  dGOTO});
end

//  ALU Operation Pipeline Register

always @(posedge Clk)
begin
    if(Rst)
        ALU_Op <= #1 12'b0;
    else if(CE)
        ALU_Op <= #1 (Skip ? 12'b0 : dALU_Op);
end

//  Literal Operand Pipeline Register

always @(posedge Clk)
begin
    if(Rst)
        KI <= #1 9'b0;
    else if(CE)
        KI <= #1 (Skip ? KI : IR[8:0]);
end

//  Unimplemented Instruction Error Register

always @(posedge Clk)
begin
    if(Rst)
        Err <= #1 0;
    else if(CE)
        Err <= #1 dErr;
end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
//  ALU Implementation - ALU[3:0] are overloaded for the four ALU elements:
//                          Arithmetic Unit, Logic Unit, Shift Unit, and Bit
//                          Processor.
//
//  ALU Operations - Arithmetic, Logic, and Shift Units
//
//  ALU_Op[1:0] = ALU Unit Operation Code
//
//      Arithmetic Unit (AU): 00 => Y = A +  B;
//                            01 => Y = A +  B + 1;
//                            10 => Y = A + ~B     = A - B - 1;
//                            11 => Y = A + ~B + 1 = A - B;
//
//      Logic Unit (LU):      00 => V = ~A;
//                            01 => V =  A & B;
//                            10 => V =  A | B;
//                            11 => V =  A ^ B;
//
//      Shift Unit (SU):      00 => S = W;                // MOVWF
//                            01 => S = {A[3:0], A[7:4]}; // SWAPF
//                            10 => S = {C, A[7:1]};      // RRF
//                            11 => S = {A[6:0], C};      // RLF
//
//  ALU_Op[3:2] = ALU Operand:
//                  A      B
//          00 =>  File    0
//          01 =>  File    W
//          10 => Literal  0
//          11 => Literal  W;
//
//  ALU Operations - Bit Processor (BP)
//
//  ALU_Op[2:0] = Bit Select: 000 => Bit 0;
//                            001 => Bit 1;
//                            010 => Bit 2;
//                            011 => Bit 3;
//                            100 => Bit 4;
//                            101 => Bit 5;
//                            110 => Bit 6;
//                            111 => Bit 7;
//
//  ALU_Op[3] = Set: 0 - Clr Selected Bit;
//                   1 - Set Selected Bit;
//
//  ALU_Op[5:4] = Status Flag Update Select
//
//          00 => None
//          01 => C
//          10 => Z
//          11 => Z,DC,C
//
//  ALU_Op[7:6] = ALU Output Data Multiplexer
//
//          00 => AU
//          01 => LU
//          10 => SU
//          11 => BP
//
//  ALU_Op[8]  = Tst: 0 - Normal Operation
//                    1 - Test: INCFSZ/DECFSZ/BTFSC/BTFSS
//
//  ALU_Op[9]  = Indirect Register, INDF, Selected
//
//  ALU_Op[10] = Write Enable Working Register (W)
//
//  ALU_Op[11] = Write Enable File {RAM | Special Function Registers}
//

assign C_In  = ALU_Op[0];  // Adder Carry input
assign B_Inv = ALU_Op[1];  // B Bus input invert
assign B_Sel = ALU_Op[2];  // B Bus select
assign A_Sel = ALU_Op[3];  // A Bus select

//  AU Input Bus Multiplexers

assign A = A_Sel ? KI : DI;
assign B = B_Sel ?  W : 0;
assign Y = B_Inv ? ~B : B;

//  AU Adder

assign {DC_In, X[3:0]} = A[3:0] + Y[3:0] + C_In;
assign {C_Out, X[7:4]} = A[7:4] + Y[7:4] + DC_In;

//  Logic Unit (LU)

assign LU_Op = ALU_Op[1:0];

always @(*)
begin
    case (LU_Op)
        2'b00 : V <= ~A;
        2'b01 : V <=  A | B;
        2'b10 : V <=  A & B;
        2'b11 : V <=  A ^ B;
    endcase
end

//  Shifter and W Multiplexer

assign S_Sel = ALU_Op[1:0];

always @(*)
begin
    case (S_Sel)
        2'b00 : S <= B;                  // Pass Working Register (MOVWF)
        2'b01 : S <= {A[3:0], A[7:4]};   // Swap Nibbles (SWAPF)
        2'b10 : S <= {C, A[7:1]};        // Shift Right (RRF)
        2'b11 : S <= {A[6:0], C};        // Shift Left (RLF)
    endcase
end

//  Bit Processor

assign Bit = ALU_Op[2:0];
assign Set = ALU_Op[3];
assign Tst = ALU_Op[8];

always @(*)
begin
    case(Bit)
        3'b000  : Msk <= 8'b0000_0001;
        3'b001  : Msk <= 8'b0000_0010;
        3'b010  : Msk <= 8'b0000_0100;
        3'b011  : Msk <= 8'b0000_1000;
        3'b100  : Msk <= 8'b0001_0000;
        3'b101  : Msk <= 8'b0010_0000;
        3'b110  : Msk <= 8'b0100_0000;
        3'b111  : Msk <= 8'b1000_0000;
    endcase
end

assign U = Set ? (DI | Msk) : (DI & ~Msk);

assign T = DI & Msk;
assign g = Tst ? (Set ? |T : ~|T) : 1'b0;

//  Output Data Mux

assign D_Sel = ALU_Op[7:6];

always @(*)
begin
    case (D_Sel)
        2'b00 : DO <= X;  // Arithmetic Unit Output
        2'b01 : DO <= V;  // Logic Unit Output
        2'b10 : DO <= S;  // Shifter Output
        2'b11 : DO <= U;  // Bit Processor Output
    endcase
end

//  Working Register

assign WE_W = CE & ALU_Op[10];

always @(posedge Clk)
begin
    if(POR)
        W <= #1 8'b0;
    else if(CE)
        W <= #1 (WE_W ? DO : W);
end

//  Z Register

assign Z_Sel = ALU_Op[5];
assign Z_Tst = ~|DO;

always @(posedge Clk)
begin
    if(POR)
        Z <= #1 1'b0;
    else if(CE)
        Z <= #1 (Z_Sel  ? Z_Tst : (WE_PSW ? DO[2] : Z));
end

//  Digit Carry (DC) Register

assign DC_Sel = ALU_Op[5] & ALU_Op[4];

always @(posedge Clk)
begin
    if(POR)
        DC <= #1 1'b0;
    else if(CE)
        DC <= #1 (DC_Sel ? DC_In : (WE_PSW ? DO[1] : DC));
end

//  Carry (C) Register

assign C_Sel = ALU_Op[4];
assign S_Dir = ALU_Op[1] & ALU_Op[0];
assign C_Drv = (~ALU_Op[7] & ~ALU_Op[6]) ? C_Out : (S_Dir ? A[7] : A[0]);

always @(posedge Clk)
begin
    if(POR)
        C <= #1 1'b0;
    else if(CE)
        C <= #1 (C_Sel  ? C_Drv : (WE_PSW ? DO[0] : C));
end

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
//  Microprocessor Core Implementation
//
//  Pipeline Instruction Register Assignments

assign GOTO      = dIR[0];
assign CALL      = dIR[1];
assign RETLW     = dIR[2];
assign WE_SLEEP  = dIR[3];
assign WE_WDTCLR = dIR[4];
assign WE_TRISA  = dIR[5];
assign WE_TRISB  = dIR[6];
assign WE_TRISC  = dIR[7];
assign WE_OPTION = dIR[8];

//  Skip Logic

always @(*)
begin
    Skip <= WE_SLEEP | WE_PCL
            | (Tst ? ((ALU_Op[7] & ALU_Op[6]) ? g    : Z_Tst)
                   : ((GOTO | CALL | RETLW)   ? 1'b1 : 1'b0 ));
end

//  File Register Address Multiplexer

assign INDF = ALU_Op[9];
assign FA   = (INDF ? FSR : (KI[4] ? {FSR[6:5], KI[4:0]} : {2'b0, KI[4:0]}));

//  File Register Write Enable

assign WE_F = ALU_Op[11];

//  Special Function Register Write Enables

assign WE_TMR0   = WE_F & (FA[4:0] == pTMR0);
assign WE_PCL    = WE_F & (FA[4:0] == pPCL);
assign WE_STATUS = WE_F & (FA[4:0] == pSTATUS);
assign WE_FSR    = WE_F & (FA[4:0] == pFSR);
assign WE_PORTA  = WE_F & (FA[4:0] == pPORTA);
assign WE_PORTB  = WE_F & (FA[4:0] == pPORTB);
assign WE_PORTC  = WE_F & (FA[4:0] == pPORTC);

//  Assign Write Enable for STATUS register Processor Status Word (PSW) bits
//      Allow write to the STATUS[2:0] bits, {Z, DC, C}, only for instructions
//      MOVWF, BCF, BSF, and SWAPF. Exclude instructions DECFSZ and INCFSZ.

assign WE_PSW = WE_STATUS & (ALU_Op[5:4] == 2'b00) & (ALU_Op[8] == 1'b0);

////////////////////////////////////////////////////////////////////////////////
//
// Program Counter Implementation
//
//  On CALL or MOVWF PCL (direct or indirect), load PCL from the ALU output
//  and the upper bits with {PA, 0}, i.e. PC[8] = 0.
//

assign Ld_PCL = CALL | WE_PCL;

always @(posedge Clk)
begin
    if(Rst)
        PC <= #1 12'hFFF;   // Set PC to Reset Vector on Rst or WDT Timeout
    else if(CE)
        PC <= #1 (GOTO ? {PA, KI}
                       : (Ld_PCL ? {PA, 1'b0, DO}
                                 : (RETLW ? TOS : PC + 1)));
end

//  Stack Implementation (2 Level Stack)

always @(posedge Clk)
begin
    if(POR)
        TOS <= #1 12'h000;  // Clr TOS on Rst or WDT Timeout
    else if(CE)
        TOS <= #1 (CALL ? PC : (RETLW ? NOS : TOS));
end

always @(posedge Clk)
begin
    if(POR)
        NOS <= #1 12'h000;  // Clr NOS on Rst or WDT Timeout
    else if(CE)
        NOS <= #1 (CALL ? TOS : NOS);
end

////////////////////////////////////////////////////////////////////////////////
//
//  Port Configuration and Option Registers

always @(posedge Clk)
begin
    if(POR) begin
        OPTION <= #1 8'b0011_1111;
        TRISA  <= #1 8'b1111_1111;
        TRISB  <= #1 8'b1111_1111;
        TRISC  <= #1 8'b1111_1111;
    end else if(CE) begin
        if(WE_OPTION) OPTION <= #1 W;
        if(WE_TRISA)  TRISA  <= #1 W;
        if(WE_TRISB)  TRISB  <= #1 W;
        if(WE_TRISC)  TRISC  <= #1 W;
    end
end

////////////////////////////////////////////////////////////////////////////////
//
//  CLRWDT Strobe Pulse Generator

always @(posedge Clk)
begin
    if(Rst)
        WDTClr <= #1 1'b0;
    else
        WDTClr <= #1 (WE_WDTCLR | WE_SLEEP) & ~PwrDn;
end

////////////////////////////////////////////////////////////////////////////////
//
//  TO (Time Out) STATUS Register Bit

assign Rst_TO = (POR | (MCLR & PD) | WE_WDTCLR);

always @(posedge Clk)
begin
    if(Rst_TO)
        TO <= #1 1'b0;
    else if(WDT_TO)
        TO <= #1 1'b1;
end

////////////////////////////////////////////////////////////////////////////////
//
//  PD (Power Down) STATUS Register Bit - Sleep Mode

assign Rst_PD = POR | (WE_WDTCLR & ~PwrDn);
assign Set_PD = WE_SLEEP;

always @(posedge Clk)
begin
    if(Rst_PD)
        PD <= #1 1'b0;
    else if(Set_PD)
        PD <= #1 1'b1;
end

//  PwrDn - Sleep Mode Control FF: Set by SLEEP instruction, cleared by Rst
//          Differs from PD in that it is not readable and does not maintain
//          its state through Reset. Gates CE to rest of the processor.

always @(posedge Clk)
begin
    if(Rst)
        PwrDn <= #1 1'b0;
    else if(WE_SLEEP)
        PwrDn <= #1 1'b1;
end

////////////////////////////////////////////////////////////////////////////////
//
//  File Register RAM

assign Addrs   = FA[3:0];
assign WE_RAMA = WE_F & ~FA[4] &  FA[3];
assign WE_RAMB = WE_F &  FA[4] & ~FA[6] & ~FA[5];
assign WE_RAMC = WE_F &  FA[4] & ~FA[6] &  FA[5];
assign WE_RAMD = WE_F &  FA[4] &  FA[6] & ~FA[5];
assign WE_RAME = WE_F &  FA[4] &  FA[6] &  FA[5];

always @(posedge Clk)
begin
    if(CE) begin
        if(WE_RAMA) RAMA[Addrs] <= #1 DO;
        if(WE_RAMB) RAMB[Addrs] <= #1 DO;
        if(WE_RAMC) RAMC[Addrs] <= #1 DO;
        if(WE_RAMD) RAMD[Addrs] <= #1 DO;
        if(WE_RAME) RAME[Addrs] <= #1 DO;
    end
end

always @(FA[6:5])
begin
    case(FA[6:5])
        2'b00 : XDO <= RAMB[Addrs];
        2'b01 : XDO <= RAMC[Addrs];
        2'b10 : XDO <= RAMD[Addrs];
        2'B11 : XDO <= RAME[Addrs];
    endcase
end

////////////////////////////////////////////////////////////////////////////////
//
// Special Function Registers

always @(posedge Clk)
begin
    if(POR) begin
        PA    <= #1 3'b0;
        FSR   <= #1 8'b0;
        PORTA <= #1 8'b1111_1111;
        PORTB <= #1 8'b1111_1111;
        PORTC <= #1 8'b1111_1111;
    end else if(CE) begin
        if(WE_STATUS) PA    <= #1 DO[7:5];
        if(WE_FSR)    FSR   <= #1 DO;
        if(WE_PORTA)  PORTA <= #1 DO;
        if(WE_PORTB)  PORTB <= #1 DO;
        if(WE_PORTC)  PORTC <= #1 DO;
    end
end

assign PA_DO = PORTA & ~TRISA;
assign PB_DO = PORTB & ~TRISB;
assign PC_DO = PORTC & ~TRISC;

//  Generate STATUS Register

assign STATUS = {PA, ~TO, ~PD, Z, DC, C};

//  Special Function Register (SFR) Multiplexers

always @(*)
begin
    case(FA[2:0])
        3'b000 :  SFR <= 8'b0;
        3'b001 :  SFR <= TMR0;
        3'b010 :  SFR <= PC[7:0];
        3'b011 :  SFR <= STATUS;
        3'b100 :  SFR <= FSR;
        3'b101 :  SFR <= {4'b0, ((PA_DI & TRISA) | PA_DO)};
        3'b110 :  SFR <= ((PB_DI & TRISB) | PB_DO);
        3'b111 :  SFR <= ((PC_DI & TRISC) | PC_DO);
    endcase
end

//  File Data Output Multiplexer

assign DI = (FA[4] ? XDO : (FA[3] ? RAMA[Addrs] : SFR));

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
//  Watchdog Timer and Timer0 Implementation- see Figure 8-6
//
//  OPTION Register Assignments

assign T0CS = OPTION[5];     // Timer0 Clock Source:   1 - T0CKI,  0 - Clk
assign T0SE = OPTION[4];     // Timer0 Source Edge:    1 - FE,     0 - RE
assign PSA  = OPTION[3];     // Pre-Scaler Assignment: 1 - WDT,    0 - Timer0
assign PS   = OPTION[2:0];   // Pre-Scaler Count: Timer0 - 2^(PS+1), WDT - 2^PS

// WDT - Watchdog Timer

assign WDT_Rst = Rst | WDTClr;

always @(posedge Clk)
begin
    if(WDT_Rst)
        WDT <= #1 0;
    else if (WDTE)
        WDT <= #1 WDT + 1;
end

//  WDT synchronous TC FF

always @(posedge Clk)
begin
    if(WDT_Rst)
        WDT_TC <= #1 0;
    else
        WDT_TC <= #1 &WDT;
end

// WDT Timeout multiplexer

assign WDT_TO = (PSA ? PSC_Pls : WDT_TC);

////////////////////////////////////////////////////////////////////////////////
//
//  T0CKI RE/FE Pulse Generator (on Input rather than after PSCntr)
//
//      Device implements an XOR on T0CKI and a clock multiplexer for the
//      Prescaler since it has two clock asynchronous clock sources: the WDT
//      or the external T0CKI (Timer0 Clock Input). Instead of this type of
//      gated clock ripple counter implementation of the Prescaler, a fully
//      synchronous implementation has been selected. Thus, the T0CKI must be
//      synchronized and the falling or rising edge detected as determined by
//      the T0CS bit in the OPTION register. Similarly, the WDT is implemented
//      using the processor clock, which means that the WDT TC pulse is in the
//      same clock domain as the rest of the logic.
//

always @(posedge Clk)
begin
    if(Rst)
        dT0CKI <= #1 3'b0;
    else begin
        dT0CKI[0] <= #1 T0CKI;                              // Synch FF #1
        dT0CKI[1] <= #1 dT0CKI[0];                          // Synch FF #2
        dT0CKI[2] <= #1 (T0SE ? (dT0CKI[1] & ~dT0CKI[0])    // Falling Edge
                              : (dT0CKI[0] & ~dT0CKI[1]));  // Rising Edge
    end
end

assign T0CKI_Pls = dT0CKI[2]; // T0CKI Pulse out, either FE/RE

//  Tmr0 Clock Source Multiplexer

assign Tmr0_CS = (T0CS ? T0CKI_Pls : CE);

////////////////////////////////////////////////////////////////////////////////
//
// Pre-Scaler Counter

assign Rst_PSC   = (PSA ? WDTClr : WE_TMR0) | Rst;
assign CE_PSCntr = (PSA ? WDT_TC : Tmr0_CS);

always @(posedge Clk)
begin
    if(Rst_PSC)
        PSCntr <= #1 8'b0;
    else if (CE_PSCntr)
        PSCntr <= #1 PSCntr + 1;
end

//  Prescaler Counter Output Multiplexer

always @(*)
begin
    case (PS)
        3'b000 : PSC_Out <= PSCntr[0];
        3'b001 : PSC_Out <= PSCntr[1];
        3'b010 : PSC_Out <= PSCntr[2];
        3'b011 : PSC_Out <= PSCntr[3];
        3'b100 : PSC_Out <= PSCntr[4];
        3'b101 : PSC_Out <= PSCntr[5];
        3'b110 : PSC_Out <= PSCntr[6];
        3'b111 : PSC_Out <= PSCntr[7];
    endcase
end

// Prescaler Counter Rising Edge Detector

always @(posedge Clk)
begin
    if(POR)
        dPSC_Out <= #1 0;
    else begin
        dPSC_Out[0] <= #1 PSC_Out;
        dPSC_Out[1] <= #1 PSC_Out & ~dPSC_Out[0];
    end
end

assign PSC_Pls = dPSC_Out[1];

////////////////////////////////////////////////////////////////////////////////
//
// Tmr0 Counter/Timer

assign CE_Tmr0 = (PSA ? Tmr0_CS : PSC_Pls);

always @(posedge Clk)
begin
    if(POR)
        TMR0 <= #1 0;
    else if(WE_TMR0)
        TMR0 <= #1 DO;
    else if(CE_Tmr0)
        TMR0 <= #1 TMR0 + 1;
end

endmodule