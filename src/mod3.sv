/*
* Module: syn_mod3_32
* Creation Date: Tue Feb 20 2000
* Author: Avrum Warshawsky
* Description: Synthetic Mod3 calculator
* Instantiated models: none
* DEFINE: WIDTH
*
*
* Description:
*
* This module will calculate mod 3 for any number up to 32 bits.
* The parameter WIDTH determines the width of the input.
* The width of the output is always 2 bits, which will be
* 0, 1, or 2 (never 3) - the MOD3 of the input data
*
*/

module syn_mod3_32 #( WIDTH=8 )
   (
    input logic [WIDTH-1:0] in,
    output logic [1:0] out
    );

//**************************************************************************
// Port Declarations
//**************************************************************************
   function [1:0] digit_mod;
      input [3:0]      digit;
      case(digit)
        4'h0: digit_mod = 2'd0;
        4'h1: digit_mod = 2'd1;
        4'h2: digit_mod = 2'd2;
        4'h3: digit_mod = 2'd0;
        4'h4: digit_mod = 2'd1;
        4'h5: digit_mod = 2'd2;
        4'h6: digit_mod = 2'd0;
        4'h7: digit_mod = 2'd1;
        4'h8: digit_mod = 2'd2;
        4'h9: digit_mod = 2'd0;
        4'ha: digit_mod = 2'd1;
        4'hb: digit_mod = 2'd2;
        4'hc: digit_mod = 2'd0;
        4'hd: digit_mod = 2'd1;
        4'he: digit_mod = 2'd2;
        4'hf: digit_mod = 2'd0;
      endcase
   endfunction

   wire [1:0]          m00, m01, m02, m03,
                       m04, m05, m06, m07;

   wire [1:0]          m10, m11, m12, m13;

   wire [1:0]          m20, m21;

   wire [31:0]         my_in = in; // Let it zero extend for us

   assign m00 = digit_mod(my_in[ 3:0 ]);
   assign m01 = digit_mod(my_in[ 7:4 ]);
   assign m02 = digit_mod(my_in[11:8 ]);
   assign m03 = digit_mod(my_in[15:12]);
   assign m04 = digit_mod(my_in[19:16]);
   assign m05 = digit_mod(my_in[23:20]);
   assign m06 = digit_mod(my_in[27:24]);
   assign m07 = digit_mod(my_in[31:28]);

   assign m10 = digit_mod({m01, m00});
   assign m11 = digit_mod({m03, m02});
   assign m12 = digit_mod({m05, m04});
   assign m13 = digit_mod({m07, m06});

   assign m20 = digit_mod({m11, m10});
   assign m21 = digit_mod({m13, m12});

   assign out = digit_mod({m21, m20});

   if (WIDTH > 32)
     $error("%t ERROR: Mod3 width must be <= 32 in %m",$realtime);
endmodule
