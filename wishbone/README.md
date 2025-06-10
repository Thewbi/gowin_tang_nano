# Gowin Educational IDE
Installation instructions are: https://wiki.sipeed.com/hardware/en/tang/common-doc/install-the-ide.html




# Links

https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html



# Wishbone Project

https://github.com/sipeed/TangNano-9K-example?tab=readme-ov-file#uart

This project will send a text each second and also echo input sent to it. 
Use a terminal emulator on the COM port opened by this example on Microsoft Windows.
A good terminal emulator is YAT (yet another terminal).
This demo also includes the blinky example.

New Project > FPGA Design Project > OK > Enter project name and path

Assumption: You are using a Tang Nano 9k
Series: GW1NR
Device: GW1NR-9

Package: ???
Speed: C6/I5
Device Version: C

There should be only a single entry left inside the list which is GW1NR-LV9QN88PC6/I5

The summary is:

```
Project
    Name: uart
    Directory: C:\Users\lapto\dev\fpga\gowin_tang_nano
    Source Directory: C:\Users\lapto\dev\fpga\gowin_tang_nano\uart\src
    Implementation Directory: C:\Users\lapto\dev\fpga\gowin_tang_nano\uart\impl

Device
    Part Number: GW1NR-LV9QN88PC6/I5
    Series: GW1NR
    Device: GW1NR-9C
    Package: QFN88P
    Speed: C6/I5
```

Create the a new verilog file:
File > New > Files > Verilog File > Name: top.v > Check: "Add to current project".

# Wishbone

## RX Client (wishbone_uart_rx_slave module)

The wishbone RX client (wishbone_uart_rx_slave module) has an input port called, slave_remote_data_source_in.
When the wishbone RX client is read using a wishbone read cycle, it will return the value that is currently placed
onto the slave_remote_data_source_in port.

The demo uses a UART RX module. When a byte of information is sent to the UART RX module, the UART RX module will
store that received byte and it will place that byte into the wishbone RX client's slave_remote_data_source_in port.
This means that first, send a byte of data to over UART, then perform a wishbone read cycle. The demo application
puts the byte read during the wishbone cycle onto the LEDs every second. Since there are only six LEDs available
on the TangNano 9k, only the lower 6 bits of the received byte are displayed using the LEDs.

In order to activate the RX demo, edit the top module and activate wishbone rx slave as well as the the wishbone RX cycle:

```
wishbone_uart_rx_slave wb_uart_rx_slave (

    // input
    .clk_i(sys_clk),
    .rst_i(~sys_rst_n),

    // input slave
    .addr_i(addr),
    .we_i(we),
    .data_i(32'h00),
    .cyc_i(cyc),
    .stb_i(stb),

    // input custom wbi
    .slave_remote_data_source_in(rx_data),

    // output slave
    .data_o(read_data),    
    .ack_o(ack)

);


reg [31:0] counter;
reg [7:0] tx_counter;

always @(posedge sys_clk)
begin
    counter = counter + 1;

    if (counter == CLK_FRE_MHZ)
    begin

        counter = 32'd0;
		
		// perform action every second
		
		// start/stop a wishbone read transaction
		start_read_transaction <= ~start_read_transaction;
		
	end
	
end
```

## TX Client (wishbone_uart_tx_slave module)

The wishbone TX client (wb_uart_tx_slave instance) has an input port called, slave_output_byte.
When the wishbone RX client is written to using a wishbone write cycle. It will return the value 
that is currently written onto to it using a wishbone write cycle to the slave_output_byte port.

The slave_output_byte is connected to a UART TX module. The TX module will transmit the written value.

The demo will transmit only a single byte (by counting up from zero to CYCLES_PER_BIT * 8 clock ticks).
Then it waits a second and transmits the data again.

To use the demo, connect a terminal emulator (Putty, Yat, teraterm, ...) to the TangNano 9k and check 
the output. A variable (tx_data) is incremented every second. The value of that variable is placed
into the wishbone master. The wishbone master performs a write cycle every second. The wishbone
slave puts the byte into the TX UART. Check your terminal. You should see a value count up from zero.

To run the TX demo, activate the TX wishbone slave and the code that transmits a byte every second.

```
wire [7:0] slave_output_byte;
wire slave_output_tx_data_valid;

wishbone_uart_tx_slave wb_uart_tx_slave (

    // input
    .clk_i(sys_clk),
    .rst_i(~sys_rst_n),

    // input slave
    .addr_i(addr),
    .we_i(we),
    .data_i(write_data), // the master places the data to write into write_data
    .cyc_i(cyc),
    .stb_i(stb),

    // input custom wbi
    .slave_remote_data_source_in(write_data), // input from the wishbone master
    .transmission_done(tx_data_ready),

    // output slave
    .data_o(write_data_ignored), // the TX slave does not use data_o. It does not return any usefull data.
    .ack_o(ack),

    // output wbi
    .slave_output_byte(slave_output_byte), // output to the UART TX module
    .slave_output_tx_data_valid(slave_output_tx_data_valid) // output to the UART TX module
);

reg [31:0] counter;
reg [7:0] tx_counter;

always @(posedge sys_clk)
begin
    counter = counter + 1;

    if (counter == CLK_FRE_MHZ)
    begin

        counter = 32'd0;

        // perform action every second
		
		// start the wishbone write transaction
        start_write_transaction = 1;
        tx_data = tx_data + 1;
		
	end

    if (counter >= (CYCLES_PER_BIT * 8))
    begin
		// stop the wishbone write transaction
        start_write_transaction = 0;
    end

end
```

# UART

## UART RX

The RX UART module first computes how many clock ticks pass per character appearing on the RX line.
The amount of ticks per character depend on the selected baudrate which is 115200 in the example and
on the clock frequency which is 27 Mhz in this example. The localparam CYCLE stores the computed clock 
ticks per character bit.

Then the RX line is sampled. In the middle, after CYCLE / 2 samples, the sampled value is used as the
actual value of that bit.

When all bits for a character have been sampled, a character has been received.

# Dual-Purpose PIN

Project > Configuration > Place & Route > Dual-Purpose Pin > Check "Use DONE as regular IO"

# Building

Next, we need to go through the build steps: 
Validate, Synthesize, Place and Route, Build Bit File, Load to FPGA.

## Synthesis

In the GOWIN IDE, open the "Process" tab > On the "Synthesis" node, open the context menu > Run.

Open the "Console" tab at the very bottom.
If the synthesis completes succesfully, you will get a line of output in the console:

```
GowinSynthesis finish
```
and on top of that line, on the "Message" tab, there should be 0 errors! 
Otherwise synthesis failed!

## Constraints

Can only be done once synthesis succeeded.

For our code to actually do anything, we must bind the ports we defined to the actual pins of the FPGA chip.

Double click the FloorPlanner in the Process interface to set pin constraints.

Let the IDE create a default constraints file.
"This project doesn't include CST file (*.cst), do you want to create a default one?" > OK

A "FloorPlanner" windows opens up.

Go to the "I/O Constraints" tab.

You need to enter the following information:

See: https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/examples/led.html


| Port		| Direction		| Location 		| I/O Type |
| --------- | ------------- | ------------- | -------- |
| led[0]    | output		| 10			| LVCMOS18 |
| led[1]	| output		| 11			| LVCMOS18 |
| led[2]	| output		| 13			| LVCMOS18 |
| led[3]	| output		| 14			| LVCMOS18 |
| led[4]	| output		| 15			| LVCMOS18 |
| led[5]	| output		| 16			| LVCMOS18 |
| uart_tx   | output        | 17			| LVCMOS33 |
| uart_rx   | input        	| 18			| LVCMOS33 |
| sys_clk   | input			| 52			| LVCMOS33 | 
| sys_rst_n | input			| 4             | LVCMOS18 |

sys_clk has to be input and LVCMOS33. sys_rst_n has to be input. The UART pins are both LVCMOS33.


Save the file and close the FloorPlanner.


## Timing Constraints

In the tree on the left, double click User Constraints > Timing Constraints Editor.
"This project doesn't include SDC file (*.sdc), do you want to create a default one?" > OK

In the tree, select the node "Clocks" > In the right editor view, open the context menu and select: Create Clock

Clock name: sys_clk
Frequency: 27 MHz
Objects: [get_ports {sys_clk}]


## Place and Route

Next, open the context menu on "Place and Route" > Run.
In the tree view on the left side, the icon on the "Place & Route" node will turn into a green check icon.

HINT: Once Place and Route is done, the bitfile has been created and can immediately be uploaded using the programmer!
There is no explicit step to create the bit stream!

## Programmer

Select the programmer button from the toolbar!









# Warning: 'sys_clk' was determined to be a clock but was not created.

During Place & Route, the system outputs the following warning:

```
WARN  (TA1132) :  'sys_clk' was determined to be a clock but was not created.
```

https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html

Solution:
In order to make this warning go away, you need to add a Timing Constraints file (*.sdc)
that adds standard constraints (27 Mhz and also correct PIN) for the default sys_clk.
To see how to do this, check the section "Timing Constraints" in this document.


