# Gowin Educational IDE
Installation instructions are: https://wiki.sipeed.com/hardware/en/tang/common-doc/install-the-ide.html




# Links

https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html



# Blinky Project

https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/examples/led.html

This project will turn on the six LEDs one by one. You should see a
small light loop from left to right and wrap around back again.

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
    Name: blinky
    Directory: C:\Users\lapto\dev\fpga\gowin_tang_nano
    Source Directory: C:\Users\lapto\dev\fpga\gowin_tang_nano\blinky\src
    Implementation Directory: C:\Users\lapto\dev\fpga\gowin_tang_nano\blinky\impl

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
module top (
    input sys_clk,          // clk input
    input sys_rst_n,        // reset input
    output reg [5:0] led    // 6 LEDS pin
);

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
| led[0]	| output		| 10			| LVCMOS18 |
| led[1]	| output		| 11			| LVCMOS18 |
| led[2]	| output		| 13			| LVCMOS18 |
| led[3]	| output		| 14			| LVCMOS18 |
| led[4]	| output		| 15			| LVCMOS18 |
| led[5]	| output		| 16			| LVCMOS18 |
| sys_clk   | input			| 52			| LVCMOS33 |
| sys_rst_n | input			| 4             | LVCMOS18 |

sys_clk has to be input and LVCMOS33. sys_rst_n has to be input.

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


