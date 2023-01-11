`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/01/2017 10:59:54 AM
// Design Name: 
// Module Name: crc_calc
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


module crc_calc(
    input clk,
    input rst,
    input [31:0] din,
    input din_en,
    input sop,
    input eop,
    input inv_crc,
    output reg [15:0] crc_dout,
    output crc_rdy
    );
    
    reg [31 : 0] crc_lo;
    reg [31 : 0] crc_hi;
    reg [31 : 0] crc32;
    reg [31 : 0] crc16;
    
    reg [2 : 0] crc_calc_state;
    
    always @(posedge clk) begin
        if(rst == 1) begin
            crc_calc_state <= 0;
            
            crc_dout <= 16'h0000;
        end else begin
            case(crc_calc_state)
                0: begin 
                    if(din_en == 1) begin
                        if(sop == 1) begin
                            crc_lo <= {16'h0000, din[15 : 0]};
                            crc_hi <= {16'h0000, din[31 : 16]};        
                        end else begin
                            crc_lo <= crc_lo + din[15 : 0];
                            crc_hi <= crc_hi + din[31 : 16];
                        end                        
                        
                        if(eop == 1) begin
                            crc_calc_state <= 1;
                        end
                    end
                end
                1: begin
                    crc32 <= crc_hi + crc_lo;
                    
                    crc_calc_state <= 2;        
                end
                2: begin
                    crc16 <= crc32[15 : 0] + crc32[31 : 16];
                    
                    crc_calc_state <= 3;    
                end
                3: begin
                    if(inv_crc == 1) begin
                        crc_dout <= ~crc16;
                    end else begin
                        crc_dout <= crc16;
                    end
                     
                    crc_calc_state <= 4;    
                end
                4: begin                                
                    crc_calc_state <= 0;    
                end
            endcase    
        end
    end
                   
    assign crc_rdy = (crc_calc_state == 4);                   
endmodule
