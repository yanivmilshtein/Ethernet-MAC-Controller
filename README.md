Hello and welcome to an educational fpga verilog project: ** Ethernet MAC controller**
This project aims to implement a simplified version of the Ethernet32 protocol, which resides in the Data Link Layer of the OSI model.
the whole module is comprised from the following sub modules:
  * MAC controller - the top module that links all the sub modules and coordinates the transmission and reception operations
  * fifo_rx - a buffer designed to temporarily handle and store ethernet packets from the PHY level
  * frame_reception - handles recieving ethernet packets from the PHY layer via the fifo_rx  module and decapsulating them for the upper layers
  * fifo_tx -a buffer designed to temporarily handle and store data from the upper layers and feed them to frame_transmission module for encapsulation
  * frame_transmission - handles constructing the ethernet32 packet to be ready for the PHY layer
  * crc_generator - a critical sub module used both in frame_transmission and frame_reception and incharge of calculating the crc bits

    --------------------------------------------------------------------------------------------------------------------------------------
    
This is an ongoing project and is coming to its final stages,

**Latest update:** currently working on the top module  "MAC controller" and ironing bugs and logical issues as they come up.

tools used in this project: 
  * VS code
  * Modelsim
  *  Quartus 18.1 lite
