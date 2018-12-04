`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
/*
Testbench for the DDS module

jca@fe.up.pt, Nov 2018

	This Verilog code is property of University of Porto
	Its utilization beyond the scope of the course Digital Systems Design
	(Projeto de Sistemas Digitais) of the Integrated Master in Electrical
	and Computer Engineering requires explicit authorization from the author.


Simulation instructions:
-----------------------

    1.Edit the script ./matlab/dds.m and adjust the following parameters to match the
	  DDS configuration you want to verify:
       duration = 0.1;       % Duration of the output test signal (seconds):
       Fs = 192000;          % Sampling frequency (Hz):
       Fout = 19000;         % required output frequency (Hz):
       Nbits_sine_LUT = 10;  % Number of bits per sample in lookup-table
       Nsamples_LUT   = 128; % Number of samples in the lookup-table (int power of 2)
       Nfrac = 6;            % Number of bits of the fractional phase:
                             % note that the number of bits in the integer part of the
                             % phase is given by log2( NsamplesLUT )

	2.Run the script dds.m in Matlab/Octave in directory ./matlab
	  This will generate the data for the DDS lookup table (file ./simdata/DDSLUT.hex)
	  and a vector with the output sine samples generated by the DDS (file ./simdata/DDSout.hex).
	  These files are ASCII with one signed data sample per line in hexadecimal format and the
	  high-order bits to the left of the Nbits_sine_LUT bit padded with zeros (only the lower
	  Nbits_sine_LUT are meaningful).
	  To use the DDSLUT.hex file to load you lookup-table (register array sineLUT),
	  you can include the following Verilog code into your module:

	  reg [31:0] sineLUT[ 0 : Nsamples_LUT-1 ];
      initial
         $readmemh("../simdata/DDSLUT.hex", sineLUT );

	  The lookup-table should be defined as a 32-bit register array, even
	  if the data samples use less bits. The output port of the DDS module
	  should only output the meaningful bits. This script also outputs the
	  required phase increment for the output frequency set.

	  This script also outputs the required phase increment
	  for the output frequency set. Register this number as it will be necessary to
	  configure the parameter PHASE_INCREMENT in the testbench

	3.Adjust in this testbench the following simulation parameters:
	     parameter FS              = 192000; // Sampling frequency
		 parameter MAX_SIM_SAMPLES = 19200;  // Maximum simulation time is 0.1 second
	     parameter N_OUTPUT_BITS   = 9;      // Number of valid bits in the output word
         parameter PHASE_INCREMENT = 32'b001100_101010; // This is 12.6562500 (binary: 001100.101010)
	                                                    // to generate a 19 kHz sine wave

	4.Setup and run the simulation in QuestaSim:
	  4.1 Create a QuestaSim project in ./sim
	  4.2 Import to the project your dds.v and this testbench (./src/verilog-tb/dds_tb.v)
	      You may need to adjust the module and signal names and define the parameters needed
		  to configure your module: number of samples in the DDS LUT, number of bits per sample and
		  number of bits of the fractional part of the phase. Note that the example of
		  instantiation included in this testbench does not define any parameter.
	  4.3 The testbench compares automatically the results generated by the DDS module with the
	      results generated by the Matlab script. If errors are found and you need to
		  analyse the signals in more detail, the signal 'outsineNbits' contains the output
		  with only the number of bits defined by parameter 'Nbits_sine_LUT'. This signal can
		  be plotted in the waveform window using radix decimal and format analog.
	  4.4 If no errors are reported for the various configurations needed, congratulations!
	      You have created a fundamental building block of the FM modulator.

	5.If the simulation succeed, you can proceed to the RTL synthesis and post-synthesis simulation,
	  using this same testbench (refer to the guide of lab project 2).

*/

//////////////////////////////////////////////////////////////////////////////////
module dds_testbench;

//-------------------------------------------
// Testbench parameters (assume Fs = 192 kHz):
// Main clock frequency will be 147.456000 MHz (48k x 256 x 6 )
parameter CLOCK_PERIOD = 1_000_000_000 / 147_456_000; // Main clock period (ns)
parameter MAX_SIM_SAMPLES = 19200;                    // Maximum simulation time is 0.1 second
parameter FS              = 192000;                   // Sampling frequency (Hz)

// The DDS module outputs 32 bits but in general we will use only less than 32 bits.
// For verification we need to connect a wire with NOUTBITS to see in the waveform window
// the correct signed output value:
parameter N_OUTPUT_BITS   = 9;                        // Number of valid bits in the output word

// Set the phase increment to 12.6562500 (binary: 001100.101010)
// To generate a 38 kHz sine wave
// For readability, use the "_" to indicate the position of the fractional point
parameter PHASE_INCREMENT = 32'b0011001_010101;


// vector to hold the golden results generated my the Matlab code:
reg [31:0]  GOLDENOUT[0: MAX_SIM_SAMPLES-1];

// The number of samples read from file (defaults to MAX_SIM_SAMPLES)
integer Nsamples = MAX_SIM_SAMPLES;

// Maximum number of errors to terminate the simulation:
parameter MAX_ERRORS = 20;

// SIMULATION FILE
// parameter file = "../simadata/DDSLUT.hex"

integer i; // generic var for loop iteration


reg         clock;       // Master clock
reg         reset;       // Master reset
reg  [31:0] phaseinc;    // The phase increment
wire [31:0] outsine;     // Output sine
wire        clken192kHz; // The clock enable setting the sampling frequency:

//-------------------------------------------
// Instantiate the DDS module:
dds #(.NBITS(13),.NBITS_SINE_LUT(7),.N_OUTPUT_BITS(N_OUTPUT_BITS),.NSAMPLES_LUT(128),.HEXVAL("../simdata/DDSLUT38.hex")) dds(
         .clock( clock ),
			.reset( reset ),
			.enableclk( clken192kHz ),
			.phaseinc( phaseinc ),
			.outsine( outsine )
    );

//-------------------------------------------
// Initialize simulation variables:
initial
begin
  clock = 0;
  reset = 0;

  // Set the phase increment to 12.6562500 (binary: 001100.101010)
  // To generate a 38 kHz sine wave
  phaseinc = PHASE_INCREMENT;

  $write("Loading file with the golden results %s\n", "../simdata/DDSLUT38.hex");

  // Load golden results:
  $readmemh( "../simdata/DDSout38.hex", GOLDENOUT );

  // Count number of samples read:
  for(i=0; i< MAX_SIM_SAMPLES; i=i+1 )
    if ( GOLDENOUT[i] === 32'dx )
	begin
	  Nsamples = i;
	  i = MAX_SIM_SAMPLES;
	end
    $write("Done. Read %1d samples.\n", Nsamples);
end

//-------------------------------------------
// generate the main clock:
initial
begin
  forever #(CLOCK_PERIOD / 2) clock = ~clock;
end

//-------------------------------------------
// generate the main reset, set to 1 during 1 clock cycle:
initial
begin
  @(posedge clock);
  @(negedge clock);
  #1
  reset = 1'b1;
  @(negedge clock);
  reset = 1'b0;
end

//-------------------------------------------
// Generate the 192 kHz clock enable:
// Divide the main clock by (256 x 3 = 768)
// Note this code is synthezisable:
reg [9:0] clkdivcount;
always @(posedge clock)
if ( reset )
  clkdivcount = 10'd0;
else
begin
  if ( clkdivcount == 767 )
    clkdivcount <= 10'd0;
  else
    clkdivcount <= clkdivcount + 10'd1;
end
assign clken192kHz = ( clkdivcount == 767 );
//-------------------------------------------


wire [N_OUTPUT_BITS-1:0] outsineNbits;
assign outsineNbits = outsine[N_OUTPUT_BITS-1:0];

//-------------------------------------------
// Verification procedure:
integer sampleindex = 0; // index to the GOLDENOUT vector
integer error_count = 0; // Counts the number of errors detected
initial
begin

  // Wait for the deactivation of the reset:
  @(posedge reset);
  # 1;
  @(negedge reset);
  # 1

  $write("Starting simulation...\n");

  sampleindex = 0;
  while ( sampleindex < MAX_SIM_SAMPLES ) // Set the maximum simulation time
  begin
    // First output sample will appear after the next clock cycle when clken192kHz==1:
    @(negedge clken192kHz);
	@(negedge clock);
	if ( GOLDENOUT[ sampleindex ] !== outsine )
	begin
	  $write("ERROR at sample %d: expected: %d, read %d\n", sampleindex, GOLDENOUT[ sampleindex ], outsine );
	  error_count = error_count + 1;
	  if ( error_count > MAX_ERRORS )
	  begin
	    sampleindex = MAX_SIM_SAMPLES;
		$write("Maximum number of errors exceeded. Terminating simulation.\n");
	  end
	end
	sampleindex = sampleindex + 1;
	if ( sampleindex % 1000 == 0 && sampleindex != 0)
	  $write("Samples verified: %1d (%3d%%)\n", sampleindex, (sampleindex*100)/MAX_SIM_SAMPLES );
  end
  if ( error_count == 0 )
 	  $write("No errors found.\n");
  else
 	  $write("Detected %1d errors.\n", error_count );

  $write("\n-----------------------------\n");
  $write("   OOO    K      \n");
  $write("  O   O   K   K  \n");
  $write("  O   O   K K    \n");
  $write("  O   O   K K    \n");
  $write("   OOO    K   K  \n");

  $write("\n-----------------------------\n\n");

  $stop;
end


endmodule
