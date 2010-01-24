/* ***********************************************************************
  The Free IP Project
  Free-RISC8 -- Verilog 8-bit Microcontroller
  (c) 1999, The Free IP Project and Thomas Coonan


  FREE IP GENERAL PUBLIC LICENSE
  TERMS AND CONDITIONS FOR USE, COPYING, DISTRIBUTION, AND MODIFICATION

  1.  You may copy and distribute verbatim copies of this core, as long
      as this file, and the other associated files, remain intact and
      unmodified.  Modifications are outlined below.  
  2.  You may use this core in any way, be it academic, commercial, or
      military.  Modified or not.  
  3.  Distribution of this core must be free of charge.  Charging is
      allowed only for value added services.  Value added services
      would include copying fees, modifications, customizations, and
      inclusion in other products.
  4.  If a modified source code is distributed, the original unmodified
      source code must also be included (or a link to the Free IP web
      site).  In the modified source code there must be clear
      identification of the modified version.
  5.  Visit the Free IP web site for additional information.
      http://www.free-ip.com

*********************************************************************** */

module cpu (
   clk,
   reset,
   
   paddr,
   pdata,
   portain,
   portbout,
   portcout,
   
   expdin,
   expdout,
   expaddr,
   expread,
   expwrite,
   
   debugw,
   debugpc,
   debuginst,
   debugstatus
);

// Basic Core I/O.
input		clk;
input		reset;

// Program memory interface
output [10:0]	paddr;
input  [11:0]	pdata;

// Basic I/O Ports
input  [7:0]	portain;
output [7:0]	portbout;
output [7:0]	portcout;

// Expansion Interface
input [7:0]	expdin;		// Data from expansion circuits TO the PIC Core
output [7:0]	expdout;	// Data to the expansion circuits FROM the PIC Core
output [6:0]	expaddr;	// File address
output		expread;	// Active high read signal (read FROM expansion circuit)
output		expwrite;	// Active high write signal (write TO expansion circuit)

// Debugging
output [7:0]	debugw;
output [10:0]	debugpc;
output [11:0]	debuginst;
output [7:0]	debugstatus;

// Register declarations for outputs
reg [10:0]	paddr;
reg [7:0]	portbout;
reg [7:0]	portcout;
reg [7:0]	expdout;
reg [6:0]	expaddr;
reg		expread;
reg		expwrite;

// This should be set to the ROM location where our restart vector is.
// As set here, we have 512 words of program space.
//
parameter RESET_VECTOR = 11'h7FF;

parameter	INDF_ADDRESS	= 3'h0,
		TMR0_ADDRESS	= 3'h1,
		PCL_ADDRESS	= 3'h2,
		STATUS_ADDRESS	= 3'h3,
		FSR_ADDRESS	= 3'h4,
		PORTA_ADDRESS	= 3'h5,
		PORTB_ADDRESS	= 3'h6,
		PORTC_ADDRESS	= 3'h7;

// *********  Special internal registers

// Instruction Register
reg  [11:0]	inst;

// Program Counter
reg  [10:0]	pc, pc_in;

// Stack Registers and Stack "levels" register.
reg [ 1:0]	stacklevel;
reg [10:0]	stack1;
reg [10:0]	stack2;

// W Register
reg [ 7:0]	w;

// The STATUS register (#3) is 8 bits wide, however, we only currently use 2 bits
// of it; the C and Z bit.
//
// bit 0  -  C
// bit 2  -  Z
//
reg [ 7:0]	status;

// The FSR register is the pointer register used for Indirect addressing (e.g. using INDF).
reg  [ 7:0]	fsr;

// Timer 0
reg  [ 7:0]	tmr0;
reg  [ 7:0]	prescaler;

// Option Register
reg [7:0]	option;

// Tristate Control registers. We do not neccessarily support bidirectional ports, but
//    will save a place for these registers and the TRIS instruction.  Use for debug.
reg [7:0]	trisa;
reg [7:0]	trisb;
reg [7:0]	trisc;

// I/O Port registers
//
reg [7:0]	porta;	// Input PORT
reg [7:0]	portb;	// Output PORT
reg [7:0]	portc;	// Output PORT

// ********** Instruction Related signals ******

reg 		skip;  // When HI force a NOP (all zeros) into inst

// Derive special sub signals from inst register
wire [ 7:0]	k;
wire [ 4:0]	fsel;
wire		d;
wire [ 2:0]	b;

// ********** File Address ************
//
// This is the 7-bit Data Address that includes the lower 5-bit fsel, the
// FSR bits and any indirect addressing.
// Use this bus to address the Register File as well as all special registers, etc.
//
reg [6:0]	fileaddr;

// Address Selects
reg		specialsel;
reg		regfilesel;
reg		expsel;

// ******  Instruction Decoder Outputs **************

// Write enable for the actual ZERO and CARRY bits within the status register.
// Generated by the Instruction Decoder.
//
wire [1:0]	aluasel;
wire [1:0]	alubsel;
wire [3:0]	aluop;

wire		zwe;
wire		cwe;

wire		isoption;
wire		istris;

wire		fwe;	// High if any "register" is being written to at all.
wire		wwe;	// Write Enable for the W register.  Produced by Instruction Decoder.

// *************  Internal Busses, mux connections, etc.  ********************

// Bit decoder bits.  
reg [7:0]	bd;	// Final decoder value after any polarity inversion.
reg [7:0]	bdec;	// e.g. "Bit Decoded"
wire		bdpol;	// Polarity bit for the bit test operations.

// Data in and out of the and out of the register file
//
reg [7:0]	regfilein;	// Input into Register File, is connected to the dbus.
wire [7:0]	regfileout;	// Path leaving the register file, goes to SBUS Mux
reg		regfilewe;	// Write Enable
reg		regfilere;	// Read Enable

//
// The dbus (Destination Bus) comes out of the ALU.  It is available to all
// writable registers.
//
// The sbus (Source Bus) comes from all readable registers as well as the output
// of the Register File.  It is one of the primary inputs into the ALU muxes.
//
// The (Expansion Bus) is another potential source.  See the 'exp' signals.
//
reg  [7:0]	dbus;
reg  [7:0]	sbus;


// ALU Signals
//
reg  [7:0]	alua;
reg  [7:0]	alub;
wire [7:0]	aluout;
wire		alucout;
wire       	aluz;

// ALU A and B mux selects.
//
parameter [1:0]	ALUASEL_W	= 2'b00,
		ALUASEL_SBUS	= 2'b01,
		ALUASEL_K	= 2'b10,
		ALUASEL_BD	= 2'b11;
		
parameter [1:0]	ALUBSEL_W	= 2'b00,
		ALUBSEL_SBUS	= 2'b01,
		ALUBSEL_K	= 2'b10,
		ALUBSEL_1	= 2'b11;

// ALU Operation codes.
//		
parameter  [3:0] ALUOP_ADD  = 4'b0000;
parameter  [3:0] ALUOP_SUB  = 4'b1000;
parameter  [3:0] ALUOP_AND  = 4'b0001;
parameter  [3:0] ALUOP_OR   = 4'b0010;
parameter  [3:0] ALUOP_XOR  = 4'b0011;
parameter  [3:0] ALUOP_COM  = 4'b0100;
parameter  [3:0] ALUOP_ROR  = 4'b0101;
parameter  [3:0] ALUOP_ROL  = 4'b0110;
parameter  [3:0] ALUOP_SWAP = 4'b0111;


// Instantiate each of our subcomponents
//
regs  regs (
   .clk		(clk), 
   .reset	(reset),
   .we  	(regfilewe),
   .re		(regfilere),
   .bank	(fileaddr[6:5]), 
   .location	(fileaddr[4:0]),
   .din		(regfilein), 
   .dout	(regfileout)
);

// Instatiate the ALU.
//
alu alu  (
   .op         (aluop), 
   .a          (alua), 
   .b          (alub),
   .y          (aluout),
   .cin        (status[0]), 
   .cout       (alucout), 
   .zout       (aluz)
);

// Instantiate the Instruction Decoder.  This is really just a lookup table.
// Given the instruction, generate all the signals we need.  
//
// For example, each instruction implies a specific ALU operation.  Some of
// these are obvious such as the ADDW uses an ADD alu op.  Less obvious is
// that a mov instruction uses an OR op which lets us do a simple copy.
// 
// Data has to funnel through the ALU, which sometimes makes for contrived
// ALU ops.
//
wire		idecwwe;
wire		idecfwe;
wire		ideczwe;
wire		ideccwe;

idec idec (
   .inst     (inst),
   .aluasel  (aluasel),
   .alubsel  (alubsel),
   .aluop    (aluop),
   .wwe      (idecwwe),
   .fwe      (idecfwe),
   .zwe      (ideczwe),
   .cwe      (ideccwe),
   .bdpol    (bdpol),
   .option   (isoption),
   .tris     (istris)
);

// Wire decoder enables to enables in at this module.  I did this because at
// one time I had another global 'enable' that was ANDed in, but I removed that.
//
assign wwe = idecwwe;
assign fwe = idecfwe;
assign zwe = ideczwe;
assign cwe = ideccwe;

// *********** Debug ****************
assign	debugw = w;
assign	debugpc = pc;
assign	debuginst = inst;
assign	debugstatus = status;

// *********** REGISTER FILE Addressing ****************
//
// We implement the following:
//    - The 5-bit fsel address is within a "BANK" which is 32 bytes.
//    - The FSR bits 6:5 are the BANK select, so there are 4 BANKS, a 
//      total of 128 bytes.  Minus the 8 special registers, that's 
//      really 120 bytes.
//    - The INDF register is for indirect addressing.  Referencing INDF
//      uses FSR as the pointer.  Therefore, using INDF/FSR you address
//      7-bits of memory.
// We DO NOT currently implement the PAGE for program (e.g. STATUS register
// bits 6:5)
//
// The fsel address *may* be zero in which case, we are to do indirect
// addressing, using FSR register as the 8-bit pointer.
//
// Otherwise, use the 5-bits of FSEL (from the Instruction itself) and 
// 2 bank bits from the FSR register (bits 6:5).
//
always @(fsel or fsr or status) begin
   if (fsel == INDF_ADDRESS) begin
      // The INDEX register is addressed.  There really is no INDEX register.
      // Use the FSR as an index, e.g. the FSR contents are the fsel.
      //
      fileaddr = fsr[6:0];
   end
   else begin
      // Use FSEL field and status bank select bits
      //
      fileaddr = {status[6:5], fsel};
   end
end

// Write Enable to Register File.  
// Assert this when the general fwe (write enable to *any* register) is true AND Register File
//    address range is specified.
//  
always @(regfilesel or fwe)
   regfilewe = regfilesel & fwe;

// Read Enable (this if nothing else, helps in debug.)
// Assert if Register File address range is specified AND the ALU is actually using some
//    data off the SBUS.
//   
always @(regfilesel or aluasel or alubsel)
   regfilere = regfilesel & ((aluasel == ALUASEL_SBUS) | (alubsel == ALUBSEL_SBUS));

// *********** Address Decodes **************
//
// Generate 3 selects: specialsel, regfilesel and expsel
//
// ** NOTE:	Must change this whenever more or few expansion addresses are
//		added or removed from the memory map.  Otherwise, the dbus mux
// 		won't be controlled properly!
//
always @(fileaddr) begin
   casex (fileaddr) // synopsys full_case parallel_case
      // This shouldn't really change.
      //
      7'bXX00XXX: // The SPECIAL Registers are lower 8 addresses, in ALL BANKS
         begin
            specialsel	= 1'b1;
            regfilesel	= 1'b0;
            expsel	= 1'b0;
         end
         
      // Adjust this case as EXPANSION locations change!
      //
      7'b11111XX: // EXPANSION Registers are the top (4) addresses
         begin
            specialsel	= 1'b0;
            regfilesel	= 1'b0;
            expsel	= 1'b1;
         end
         
      // Assume everything else must be the Register File..
      //
      default:
         begin
            specialsel	= 1'b0;
            regfilesel	= 1'b1;
            expsel	= 1'b0;
         end
   endcase
end
  

// *********** Expansion Interface **************

always @(dbus)
   expdout = dbus;
   
always @(fileaddr)
   expaddr = fileaddr;

always @(expsel or aluasel or alubsel)
   expread = expsel & ((aluasel == ALUASEL_SBUS) | (alubsel == ALUBSEL_SBUS));

always @(expsel or fwe)
   expwrite = expsel & fwe;


//
// *********** SBUS **************
// The sbus (Source Bus) is the output of a multiplexor that takes
// inputs from the Register File, and all other special registers
// and input ports.  The Source Bus then, one of the inputs to the ALU


// First MUX selects from all the special regsiters
//
always @(fsel or fsr or tmr0 or pc or status
         or porta or portb or portc or regfileout or expdin
         or specialsel or regfilesel or expsel) begin
         
   // For our current mix of registers and peripherals, only the first 8 addresses
   // are "special" registers (e.g. not in the Register File).  As more peripheral
   // registers are added, they must be muxed into this MUX as well.
   //
   // We currently prohibit tristates.
   //
   //
   if (specialsel) begin
      // Special register
      case (fsel[2:0]) // synopsys parallel_case full_case
         3'h0:	sbus = fsr;
         3'h1:	sbus = tmr0;
         3'h2:	sbus = pc[7:0];
         3'h3:	sbus = status;
         3'h4:	sbus = fsr;
         3'h5:	sbus = porta; // PORTA is an input-only port
         3'h6:	sbus = portb; // PORTB is an output-only port
         3'h7:	sbus = portc; // PORTC is an output-only port
      endcase
   end
   else begin
      //
      // Put whatever address equation is neccessary here.  Remember to remove unnecessary
      // memory elements from Register File (regs.v).  It'll still work, but they'd be
      // wasted flip-flops.
      //
      if (expsel) begin
         sbus = expdin;
      end
      else begin
         if (regfilesel) begin
            // Final Priority is Choose the register file
            sbus = regfileout;
         end
         else begin
            sbus = 8'h00;
         end
      end
   end
end

// ************** DBUS ******
//  The Destination bus is just the output of the ALU.
//
always @(aluout)
   dbus = aluout;

always @(dbus)
   regfilein = dbus;
   
// Drive the ROM address bus straight from the PC_IN bus
//
always @(pc_in)
   paddr = pc_in;


// Define sub-signals out of inst
//
assign k =     inst[7:0];
assign fsel  = inst[4:0];
assign d     = inst[5];
assign b     = inst[7:5];

// Bit Decoder.
//
// Simply take the 3-bit b field in the PIC instruction and create the
// expanded 8-bit decoder field, which is used as a mask.
//


always @(b) begin
   case (b) // synopsys parallel_case
      3'b000: bdec = 8'b00000001;
      3'b001: bdec = 8'b00000010;
      3'b010: bdec = 8'b00000100;
      3'b011: bdec = 8'b00001000;
      3'b100: bdec = 8'b00010000;
      3'b101: bdec = 8'b00100000;
      3'b110: bdec = 8'b01000000;
      3'b111: bdec = 8'b10000000;
   endcase
end

always @(bdec or bdpol)
   bd = (bdpol) ? ~bdec : bdec;

// Instruction regsiter usually get the ROM data as its input, but
// sometimes for branching, the skip signal must cause a NOP.
//
always @(posedge clk) begin
   if (reset) begin
      inst <= 12'h000;
   end
   else begin
      if (skip == 1'b1) begin
         inst <= 12'b000000000000; // FORCE NOP
      end
      else begin
         inst <= pdata;
      end
   end
end

// SKIP signal.
//
// We want to insert the NOP instruction for the following conditions:
//    GOTO,CALL and RETLW instructions (All have inst[11:10] = 2'b10
//    BTFSS instruction when aluz is HI  (
//    BTFSC instruction when aluz is LO
//
always @(inst or aluz) begin
   casex ({inst, aluz}) // synopsys parallel_case
      13'b10??_????_????_?:    // A GOTO, CALL or RETLW instructions
         skip = 1'b1;
         
      13'b0110_????_????_1:    // BTFSC instruction and aluz == 1
         skip = 1'b1;
	
      13'b0111_????_????_0:    // BTFSS instruction and aluz == 0
         skip = 1'b1;
      
      13'b0010_11??_????_1:    // DECFSZ instruction and aluz == 1
         skip = 1'b1;
	
      13'b0011_11??_????_1:    // INCFSZ instruction and aluz == 1
         skip = 1'b1;
	
      default:
         skip = 1'b0;
   endcase
end

// 4:1 Data MUX into alua
//
//
always @(aluasel or w or sbus or k or bd) begin
   case (aluasel) // synopsys parallel_case
      2'b00: alua = w;
      2'b01: alua = sbus;
      2'b10: alua = k;
      2'b11: alua = bd;
   endcase
end

// 4:1 Data MUX into alub
//
//
always @(alubsel or w or sbus or k) begin
   case (alubsel) // synopsys parallel_case
      2'b00: alub = w;
      2'b01: alub = sbus;
      2'b10: alub = k;
      2'b11: alub = 8'b00000001;
   endcase
end

// W Register
always @(posedge clk) begin
   if (reset) begin
      w <= 8'h00;
   end
   else begin
      if (wwe) begin
         w <= dbus;
      end
   end   
end

// ************ Writes to various Special Registers (fsel between 0 and 7)

// INDF Register (Register #0)
//
//    Not a real register.  This is the Indirect Addressing mode register.
//    See the regfileaddr logic.

// TMR0 Register (Register #1)
//
//    Timer0 is currently only a free-running timer clocked by the main system clock.
//
always @(posedge clk) begin
   if (reset) begin
      tmr0 <= 8'h00;
   end
   else begin
      // See if the status register is actually being written to
      if (fwe & specialsel & (fileaddr[2:0] == TMR0_ADDRESS)) begin
         // Yes, so just update the register from the dbus
         tmr0 <= dbus;
      end
      else begin
         if (~option[5]) begin
            // OPTION[3]  -  Assigns prescaler to either WDT or TIMER0.  We don't implement WDT.
            //               If this bit is 0, then use the prescaler.  If 1 then increment.
            //
            // Mask off the prescaler value based on desired divide ratio.
            // Whenever this is zero, then that is our divided pulse.  Increment
            // the final timer value when it's zero.
            //
            casex (option[3:0]) // synopsys parallel_case full_case
               4'b1XXX: tmr0 <= tmr0 + 1;
               4'b0000: if (~|(prescaler & 8'b00000001)) tmr0 <= tmr0 + 1;
               4'b0001: if (~|(prescaler & 8'b00000011)) tmr0 <= tmr0 + 1;
               4'b0010: if (~|(prescaler & 8'b00000111)) tmr0 <= tmr0 + 1;
               4'b0011: if (~|(prescaler & 8'b00001111)) tmr0 <= tmr0 + 1;
               4'b0100: if (~|(prescaler & 8'b00011111)) tmr0 <= tmr0 + 1;
               4'b0101: if (~|(prescaler & 8'b00111111)) tmr0 <= tmr0 + 1;
               4'b0110: if (~|(prescaler & 8'b01111111)) tmr0 <= tmr0 + 1;
               4'b0111: if (~|(prescaler & 8'b11111111)) tmr0 <= tmr0 + 1;
            endcase            
         end
      end
   end
end

// The prescaler is always counting from 00 to FF whenever OPTION[5] is cleared (e.g. T0CS)
always @(posedge clk) begin
   if (reset) begin
      prescaler <= 8'h00;
   end
   else begin
      if (~option[5]) begin
         prescaler <= prescaler + 1;
      end
   end
end

// PCL Register (Register #2)
//
//    PC Lower 8 bits.  This is handled in the PC section below...


// STATUS Register (Register #3)
//
parameter STATUS_RESET_VALUE = 8'h18;

always @(posedge clk) begin
   if (reset) begin
      status <= STATUS_RESET_VALUE;
   end
   else begin
      // See if the status register is actually being written to
      if (fwe & specialsel & (fileaddr[2:0] == STATUS_ADDRESS)) begin
         // Yes, so just update the register from the dbus
         status <= dbus;
      end
      else begin
         // Update status register on a bit-by-bit basis.
         //
         // For the carry and zero flags, each instruction has its own rule as
         // to whether to update this flag or not.  The instruction decoder is
         // providing us with an enable for C and Z.  Use this to decide whether
         // to retain the existing value, or update with the new alu status output.
         //
         status <= {
            status[7],			// BIT 7: Undefined.. (maybe use for debugging)
            status[6],			// BIT 6: Program Page, HI bit
            status[5],			// BIT 5: Program Page, LO bit
            status[4],			// BIT 4: Time Out bit (not implemented at this time)
            status[3],			// BIT 3: Power Down bit (not implemented at this time)
            (zwe) ? aluz : status[2],	// BIT 2: Z
            status[1],			// BIT 1: DC
            (cwe) ? alucout : status[0]	// BIT 0: C
         };
      end
   end
end

// FSR Register  (Register #4)
//            
always @(posedge clk) begin
   if (reset) begin
      fsr <= 8'h00;
   end
   else begin
      // See if the status register is actually being written to
      if (fwe & specialsel & (fileaddr[2:0] == FSR_ADDRESS)) begin
         fsr <= dbus;
      end
   end
end

// OPTION Register
//
// The special OPTION instruction should move W into the OPTION register.
//
parameter OPTION_RESET_VALUE = 8'h3F;
always @(posedge clk) begin
   if (reset) begin
      option <= OPTION_RESET_VALUE;
   end
   else begin
      if (isoption)
         option <= dbus;
   end   
end

// PORTA Input Port   (Register #5)
//
// Register anything on the module's porta input on every single clock.
//
always @(posedge clk)
   if (reset) porta <= 8'h00;
   else       porta <= portain;

// PORTB Output Port  (Register #6)
always @(posedge clk) begin
   if (reset) begin
      portb <= 8'h00;
   end
   else begin
      if (fwe & specialsel & (fileaddr[2:0] == PORTB_ADDRESS) & ~istris) begin
         portb <= dbus;
      end
   end   
end

// Connect the output ports to the register output.
always @(portb)
   portbout = portb;
   
// PORTC Output Port  (Register #7)
always @(posedge clk) begin
   if (reset) begin
      portc <= 8'h00;
   end
   else begin
      if (fwe & specialsel & (fileaddr[2:0] == PORTC_ADDRESS) & ~istris) begin
         portc <= dbus;
      end
   end   
end

// Connect the output ports to the register output.
always @(portc)
   portcout = portc;
 
// TRIS Registers
always @(posedge clk) begin
   if (reset) begin
      trisa <= 8'hff; // Default is to tristate them
   end
   else begin
      if (fwe & specialsel & (fileaddr[2:0] == PORTA_ADDRESS) & istris) begin
         trisa <= dbus;
      end
   end   
end

always @(posedge clk) begin
   if (reset) begin
      trisb <= 8'hff; // Default is to tristate them
   end
   else begin
      if (fwe & specialsel & (fileaddr[2:0] == PORTB_ADDRESS) & istris) begin
         trisb <= dbus;
      end
   end   
end

always @(posedge clk) begin
   if (reset) begin
      trisc <= 8'hff; // Default is to tristate them
   end
   else begin
      if (fwe & specialsel & (fileaddr[2:0] == PORTC_ADDRESS) & istris) begin
         trisc <= dbus;
      end
   end   
end
  

// ********** PC AND STACK *************************
//
// There are 4 ways to change the PC.  They are:
//    GOTO  101k_kkkk_kkkk
//    CALL  1001_kkkk_kkkk
//    RETLW 1000_kkkk_kkkk
//    MOVF  0010_0010_0010  (e.g. a write to reg #2)
//    MOVWF 0000_0010_0010  (write from W to reg #2)
//
// Remember that the skip instructions work by inserting
// a NOP instruction or not into program stream and don't
// change the PC.
//


// Implmenent PC
//
// Seperate the PC_IN input bus into PC from the sequential register so that we
// can feed the PC_IN bus into the PRAM address input.

always @(posedge clk)
   if (reset) pc <= RESET_VECTOR;
   else       pc <= pc_in;

always @(inst or stacklevel or status or stack1 or stack2 or pc or dbus) begin
   casex ({inst, stacklevel}) // synopsys parallel_case
      14'b101?_????_????_??: pc_in = {status[6:5],       inst[8:0]};	// GOTO
      14'b1001_????_????_??: pc_in = {status[6:5], 1'b0, inst[7:0]};	// CALL
      14'b1000_????_????_00: pc_in = stack1;				// RETLW
      14'b1000_????_????_01: pc_in = stack1;				// RETLW
      14'b1000_????_????_10: pc_in = stack2;				// RETLW
      14'b1000_????_????_11: pc_in = stack2;				// RETLW
      14'b00?0_0010_0010_??: pc_in = {pc[10:8], dbus};		// MOVF or MOVWF where f=PC
      default:
         pc_in = pc + 1;
   endcase
end


// Implement STACK1 and STACK2 registers
//
// The Stack registers are only fed from the PC itself!
//
always @(posedge clk) begin
   if (reset) begin
      stack1 <= 9'h000;
   end
   else begin
      // CALL instruction
      if (inst[11:8] == 4'b1001) begin
         case (stacklevel) // synopsys parallel_case
            2'b00:
               // No previous CALLs 
               begin
                  stack1 <= pc;
               end
            2'b01:
               // ONE previous CALL 
               begin
                  stack2 <= pc;
               end
            2'b10:
               // TWO previous CALLs -- This is illegal on the 16C5X! 
               begin
                  $display ("Too many CALLs!!");
               end
            2'b11: 
               begin
                  $display ("Too many CALLs!!");
               end
         endcase
      end
   end
end

// Write to stacklevel
//
// The stacklevel register keeps track of the current stack depth.  On this
// puny processor, there are only 2 levels (you could fiddle with this and
// increase the stack depth).  There are two stack registers, stack1 and stack2.
// The stack1 register is used first (e.g. the first time a call is performed),
// then stack2.  As CALLs are done, stacklevel increments.  Conversely, as
// RETs are done, stacklevel goes down. 

always @(posedge clk) begin
   if (reset == 1'b1) begin
      stacklevel <= 2'b00;  // On reset, there should be no CALLs in progress
   end
   else begin
      casex ({inst, stacklevel}) // synopsys parallel_case
         // Call instructions
         14'b1001_????_????_00: stacklevel <= 2'b01;  // Record 1st CALL
         14'b1001_????_????_01: stacklevel <= 2'b10;  // Record 2nd CALL
         14'b1001_????_????_10: stacklevel <= 2'b10;  // Already 2! Ignore
         14'b1001_????_????_11: stacklevel <= 2'b00;  // {shouldn't happen}

         // Return instructions
         14'b1000_????_????_00: stacklevel <= 2'b00;  // {shouldn't happen}
         14'b1000_????_????_01: stacklevel <= 2'b00;  // Go back to no CALL in progress
         14'b1000_????_????_10: stacklevel <= 2'b01;  // Go back to 1 CALL in progress
         14'b1000_????_????_11: stacklevel <= 2'b10;  // {shouldn't happen} sort of like, Go back to 2 calls in progress
         default:
            stacklevel <= stacklevel;
      endcase
   end
end

// *******  Debug Stuff  ******** //
//
// The following is NOT synthesizable.  This code simply allows you to see the ASCII name
// for the instruction in the INST register while in a waveform viewer.
//
// synopsys translate_off
reg [8*8-1:0] inst_string;

always @(inst) begin
   casex (inst)
      12'b0000_0000_0000: inst_string = "NOP     ";
      12'b0000_001X_XXXX: inst_string = "MOVWF   ";
      12'b0000_0100_0000: inst_string = "CLRW    ";
      12'b0000_011X_XXXX: inst_string = "CLRF    ";
      12'b0000_10XX_XXXX: inst_string = "SUBWF   ";
      12'b0000_11XX_XXXX: inst_string = "DECF    ";
      12'b0001_00XX_XXXX: inst_string = "IORWF   ";
      12'b0001_01XX_XXXX: inst_string = "ANDWF   ";
      12'b0001_10XX_XXXX: inst_string = "XORWF   ";
      12'b0001_11XX_XXXX: inst_string = "ADDWF   ";
      12'b0010_00XX_XXXX: inst_string = "MOVF    ";
      12'b0010_01XX_XXXX: inst_string = "COMF    ";
      12'b0010_10XX_XXXX: inst_string = "INCF    ";
      12'b0010_11XX_XXXX: inst_string = "DECFSZ  ";
      12'b0011_00XX_XXXX: inst_string = "RRF     ";
      12'b0011_01XX_XXXX: inst_string = "RLF     ";
      12'b0011_10XX_XXXX: inst_string = "SWAPF   ";
      12'b0011_11XX_XXXX: inst_string = "INCFSZ  ";

      // *** Bit-Oriented File Register Operations
      12'b0100_XXXX_XXXX: inst_string = "BCF     ";
      12'b0101_XXXX_XXXX: inst_string = "BSF     ";
      12'b0110_XXXX_XXXX: inst_string = "BTFSC   ";
      12'b0111_XXXX_XXXX: inst_string = "BTFSS   ";

      // *** Literal and Control Operations
      12'b0000_0000_0010: inst_string = "OPTION  ";
      12'b0000_0000_0011: inst_string = "SLEEP   ";
      12'b0000_0000_0100: inst_string = "CLRWDT  ";
      12'b0000_0000_0101: inst_string = "TRIS    ";
      12'b0000_0000_0110: inst_string = "TRIS    ";
      12'b0000_0000_0111: inst_string = "TRIS    ";
      12'b1000_XXXX_XXXX: inst_string = "RETLW   ";
      12'b1001_XXXX_XXXX: inst_string = "CALL    ";
      12'b101X_XXXX_XXXX: inst_string = "GOTO    ";
      12'b1100_XXXX_XXXX: inst_string = "MOVLW   ";
      12'b1101_XXXX_XXXX: inst_string = "IORLW   ";
      12'b1110_XXXX_XXXX: inst_string = "ANDLW   ";
      12'b1111_XXXX_XXXX: inst_string = "XORLW   ";

      default:            inst_string = "-XXXXXX-";
   endcase
end
   
// synopsys translate_on

endmodule
