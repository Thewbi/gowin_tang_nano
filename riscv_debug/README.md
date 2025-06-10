# Gowin Educational IDE
Installation instructions are: https://wiki.sipeed.com/hardware/en/tang/common-doc/install-the-ide.html




# Links

https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html



# JTAG Project

## Introduction / Strategy

### Iteration 1

In iteration 1, the only thing to achieve is to have the JTAG clock line and the JTAG TMS line connected.
Then a JTAG adapter (FTDI 232H) is used to move the sample state machine through it's states.

First, lets select free pins. The requirement is that the pins for JTAG clock and JTAG TMS need to be
3v3 tolerant as the JTAG adapter will provide these signals with a 3v3 strength. Looking at doc/Pinput.gif
(which was downloaded from https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html) we can
see that the Tang Nano 9k has three banks. The banks are BANK1, BANK2 and BANK3. doc/Pinput.gif also
says in the legend at the bottom of the image, that BANK1 and BANK2 are 3v3 tolerant whereas BANK3 is 1v8
tolerant. This means none of the pins in BANK3 can be used. We are left with pins in BANK1 and BANK2.

The workflow mandated by GOWIN FPGA Designer is that in the first step, define input, output ports in the top-level module.
Perform Synthesis and Place and Route. The Floor Planner tool will now automatically list the ports in the list view of
the I/O Constraints tab. You can now drag pins from the chip view into the pins in the list view. This will assign the
pin to the port. You can then further configure the pins by setting pull mode, voltage levels and other properties.
The FloorPlanner ultimately saves your changes into the constraints file jtag.cst.

As an alternative, it is possible to copy lines into the constraints file (jtag.cst) directly. This will have the same 
effect as using the floor planner util's drag and drop approach. We will use this alternative approach.

Lets check pins 25 (IOB8A) and 26 (IOB8B). They are part of BANK2 and hence are 3v3 tolerant. They have no
special pin function and are not used by any onboard component. In the FloorPlaner of the GOWIN FPGA Designer
IDE, pins 25 and 26 are bottom left on the "Chip Array" tab.

Looking at the README.md of https://github.com/harbaum/Pacman-TangNano9k this project also uses IOB8A and IOB8B.
In total it uses six GPIOs. The constraints are copied from: https://github.com/harbaum/Pacman-TangNano9k/blob/main/tangnano9k/src/pacman.cst

```
IO_LOC "btn_up" 25;
IO_PORT "btn_up" PULL_MODE=UP;
IO_LOC "btn_down" 26;
IO_PORT "btn_down" PULL_MODE=UP;
IO_LOC "btn_left" 27;
IO_PORT "btn_left" PULL_MODE=UP;
IO_LOC "btn_right" 28;
IO_PORT "btn_right" PULL_MODE=UP;
IO_LOC "btn_coin" 29;
IO_PORT "btn_coin" PULL_MODE=UP;
IO_LOC "btn_start" 30;
IO_PORT "btn_start" PULL_MODE=UP;
```

Here are the constraints that we will use for this JTAG sample Iteration 1.
Add these constraints to gowin_tang_nano\jtag\src\jtag.cst

```
// GPIO
IO_LOC "jtag_clk" 25;
IO_PORT "jtag_clk" IO_TYPE=LVCMOS33 PULL_MODE=UP BANK_VCCIO=3.3;
IO_LOC "jtag_tms" 26;
IO_PORT "jtag_tms" IO_TYPE=LVCMOS33 PULL_MODE=UP BANK_VCCIO=3.3;
IO_LOC "jtag_tdi" 27;
IO_PORT "jtag_tdi" IO_TYPE=LVCMOS33 PULL_MODE=UP BANK_VCCIO=3.3;
IO_LOC "jtag_tdo" 28;
IO_PORT "jtag_tdo" IO_TYPE=LVCMOS33 PULL_MODE=UP BANK_VCCIO=3.3;
```

Here are the constraint settings.

| Port		| Direction		| Location 		| I/O Type |
| --------- | ------------- | ------------- | -------- |
| jtag_clk  | intput		| 25			| LVCMOS33 |
| jtag_tdi  | input         | 27            | LVCMOS33 |
| jtag_tdo  | output        | 28            | LVCMOS33 |
| jtag_tms	| intput		| 26			| LVCMOS33 |

The product page of the FT232H is: https://ftdichip.com/products/ft232hq/
The datasheet is: https://ftdichip.com/wp-content/uploads/2024/09/DS_FT232H.pdf

The application note for JTAG is: 

Here is how to connect the FT232H board (https://www.amazon.de/FT232H-Hochgeschwindigkeits-Multifunktionsmodul-I2C-Modul-Debuggen-Programmieren/dp/B0811WTD4N/ref=asc_df_B0811WTD4N?mcid=d451df40f0a3368fb16aecaf08685201&th=1&psc=1&hvocijid=5223380134859239549-B0811WTD4N-&hvexpln=75&tag=googshopde-21&linkCode=df0&hvadid=696184104678&hvpos=&hvnetw=g&hvrand=5223380134859239549&hvpone=&hvptwo=&hvqmt=&hvdev=c&hvdvcmdl=&hvlocint=&hvlocphy=9042225&hvtargid=pla-2281435176138&psc=1&gad_source=1) 
to the Tang Nano 9K

| Port		| FT232H		         | TangNano 9k 	 |
| --------- | ---------------------- | ------------- |
| jtag_clk  | AD0, AD_BUS_0 (output) | 25			 |
| jtag_tdi  | AD1, AD_BUS_1 (input)  | 28 (jtag_tdo) |
| jtag_tdo  | AD2, AD_BUS_2 (output) | 27 (jtag_tdi) |
| jtag_tms	| AD3, AD_BUS_3	(output) | 26			 |

TDO on one device is connected to TDI on the other.

#### Erros and Warnings

In the Floor Planner "Message" tab, you could potentially receive these warnings:

```
> WARN  (CT1135) : "C:/Users/lapto/dev/fpga/gowin_tang_nano/jtag/src/jtag.cst":11 | Can't find object named 'jtag_clk'
> WARN  (CT1135) : "C:/Users/lapto/dev/fpga/gowin_tang_nano/jtag/src/jtag.cst":12 | Can't find object named 'jtag_clk'
> WARN  (CT1135) : "C:/Users/lapto/dev/fpga/gowin_tang_nano/jtag/src/jtag.cst":13 | Can't find object named 'jtag_tms'
> WARN  (CT1135) : "C:/Users/lapto/dev/fpga/gowin_tang_nano/jtag/src/jtag.cst":14 | Can't find object named 'jtag_tms'
```

Solution: The input / output ports do not exist in the top-level module. In order to assign constraints to pins,
the pins first need to be defined in the top-level module, then perform synthesis and place and route. The Floor Planner
will then recognize the pin names and let you configure the pins with constraints.

First, add the pin definitions to the top level module:

```
module top(
    input sys_clk,          // clk input
    input sys_rst_n,        // reset input button  (active low)
	input uart_rx,          // UART RX
    input btn1_n,           // push button 1 (active low)

    input jtag_clk,
    input jtag_tms,

    output wire [5:0] led,   // 6 LEDS pin
	output uart_tx          // UART TX
);
```

Secondly, perform Synthesis and Place & Route on the "Process" tab.

Thirdly, open the Floor Planner. The warning messages should be gone and the pins should appera inside the list view of
the "I/O Constraints" tab.

### Iteration 2

Replace the sample state machine by the real JTAG state machine.

## Push Button

```
IO_LOC "btn1_n" 3;
IO_PORT "btn1_n" PULL_MODE=UP;
IO_LOC "btn2_n" 4;
IO_PORT "btn2_n" PULL_MODE=UP;
```

## Project Creation in GOWIN FPGA Designer

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

Add this code: (Stolen from: https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/examples/led.html)

```
// the state machine that runs the demo application has three states: IDLE, SEND and WAIT
//
// IDLE is entered on reset. IDLE immediately transitions to SEND.
// IDLE does not perform any action.
//
// SEND is entered after IDLE and when the wait period is over.
// During SEND a string of DATA_NUM characters is transmitted, one
// character per clock tick. Once all characters are transmitted,
// the transition to WAIT takes place because the demo wants to 
// wait around for some time before sending DATA_NUM characters again.
//
// In WAIT, the system remains still whithout sending data for one
// second. WAIT is the only state, where the system checks for incoming data.
// If a byte is received, that exact byte is immediately sent out over the tx line.
// 

module top(
    input sys_clk,          // clk input
    input sys_rst_n,        // reset input
	input uart_rx,          // UART RX

    output reg [5:0] led,   // 6 LEDS pin
	output uart_tx          // UART TX
);

//
// UART demo application
//

parameter                        CLK_FRE  = 27; // Mhz. The Tang Nano 9K has a 27 Mhz clock source on board
parameter                        UART_FRE = 115200; // baudrate

// the state machine that runs the demo application has three states IDLE, SEND and WAIT
localparam                       IDLE = 0;
localparam                       SEND = 1; // send 
localparam                       WAIT = 2; // wait 1 second and send uart received data

reg[7:0]                         tx_data;
reg[7:0]                         tx_str;
reg                              tx_data_valid;
wire                             tx_data_ready;
reg[7:0]                         tx_cnt;
wire[7:0]                        rx_data;
wire                             rx_data_valid;
wire                             rx_data_ready;
reg[31:0]                        wait_cnt;
reg[3:0]                         state;

assign rx_data_ready = 1'b1; // always can receive data,

always@(posedge sys_clk or negedge sys_rst_n)
begin
	if (sys_rst_n == 1'b0)
	begin
		wait_cnt <= 32'd0;
		tx_data <= 8'd0;
		state <= IDLE;
		tx_cnt <= 8'd0;
		tx_data_valid <= 1'b0;
	end
	else
    begin
        case(state)

            IDLE:
            begin
                state <= SEND;
            end

            SEND:
            begin
                wait_cnt <= 32'd0;
                tx_data <= tx_str;

                if (tx_data_valid == 1'b1 && tx_data_ready == 1'b1 && tx_cnt < DATA_NUM - 1) // send 12 bytes data
                begin
                    tx_cnt <= tx_cnt + 8'd1; // increment send data counter
                end
                else if (tx_data_valid == 1'b1 && tx_data_ready == 1'b1) // last byte sent is complete
                begin
                    tx_cnt <= 8'd0;
                    tx_data_valid <= 1'b0;
                    state <= WAIT;
                end
                else if (~tx_data_valid)
                begin
                    tx_data_valid <= 1'b1;
                end
            end

            WAIT:
            begin
                // increment the wait counter
                wait_cnt <= wait_cnt + 32'd1;

                if (rx_data_valid == 1'b1)
                begin
                    tx_data_valid <= 1'b1; // tell the tx uart that data is ready for transmission
                    tx_data <= rx_data; // send received data
                end
                else if (tx_data_valid && tx_data_ready)
                begin
                    tx_data_valid <= 1'b0; // if the tx uart signals that the character has been sent, turn of tx_data_valid
                end
                else if (wait_cnt >= CLK_FRE * 1000_000) // wait for 1 second
                begin
                    state <= SEND; // if the waiting period is over, transition back to SEND
                end
            end

            default:
            begin
                state <= IDLE;
            end

        endcase
    end
end

//
// combinational logic
//

// `define example_1

`ifdef example_1

// Example 1

parameter 	ENG_NUM  = 14; // 非中文字符数
parameter 	CHE_NUM  = 2 + 1; //  中文字符数
parameter 	DATA_NUM = CHE_NUM * 3 + ENG_NUM; // 中文字符使用UTF8，占用3个字节
wire [ DATA_NUM * 8 - 1:0] send_data = { "你好 Tang Nano 20K", 16'h0d0a };

`else

// Example 2

parameter 	ENG_NUM  = 19 + 1; // 非中文字符数
parameter 	CHE_NUM  = 0; // 中文字符数
parameter 	DATA_NUM = CHE_NUM * 3 + ENG_NUM + 1; // 中文字符使用UTF8，占用3个字节
wire [ DATA_NUM * 8 - 1:0] send_data = { "Hello Tang Nano 20K", 16'h0d0a };

`endif

always@(*)
	tx_str <= send_data[(DATA_NUM - 1 - tx_cnt) * 8 +: 8];

uart_rx#
(
	.CLK_FRE(CLK_FRE),
	.BAUD_RATE(UART_FRE)
) uart_rx_inst
(
	.clk                        (sys_clk),
	.rst_n                      (sys_rst_n),
	.rx_data                    (rx_data),
	.rx_data_valid              (rx_data_valid),
	.rx_data_ready              (rx_data_ready),
	.rx_pin                     (uart_rx)
);

uart_tx#
(
	.CLK_FRE(CLK_FRE),
	.BAUD_RATE(UART_FRE)
) uart_tx_inst
(
	.clk                        (sys_clk),
	.rst_n                      (sys_rst_n),
	.tx_data                    (tx_data),
	.tx_data_valid              (tx_data_valid),
	.tx_data_ready              (tx_data_ready),
	.tx_pin                     (uart_tx)
);

//
// LED demo application
//

reg [23:0] counter;

// update the counter variable
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        counter <= 24'd0;
    else if (counter < 24'd1349_9999)       // 0.5s delay
        counter <= counter + 1'b1;
    else
        counter <= 24'd0;
end


// update the LEDs
always @(posedge sys_clk or negedge sys_rst_n) begin
    if (!sys_rst_n)
        led <= 6'b111110;
    else if (counter == 24'd1349_9999)       // 0.5s delay
        //led[5:0] <= {led[4:0],led[5]};    // left to right
        led[5:0] <= {led[0], led[5:1]};     // right to left
    else
        led <= led;
end

endmodule
```

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


