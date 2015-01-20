module mkWire(IN_WRITE, IN_EN_WRITE, OUT_READ);
  parameter width = 1;
  input [((width == 0)? 0: width-1):0] IN_WRITE;
  output [((width == 0)? 0: width-1):0] OUT_READ;
  input IN_EN_WRITE;

  assign OUT_READ = IN_WRITE;
endmodule

module mkPULSE(IN_EN_WRITE, OUT_READ);
  output OUT_READ;
  input IN_EN_WRITE;

  assign OUT_READ = IN_EN_WRITE;
endmodule

module mkREG(CLK, RST_N, IN_WRITE, OUT_READ, IN_EN_WRITE);
  parameter width = 1;
  parameter init = 0;
  input [((width == 0)? 0: width-1):0] IN_WRITE;
  output reg [((width == 0)? 0: width-1):0] OUT_READ;
  input IN_EN_WRITE, CLK, RST_N;

  initial
    OUT_READ = init;

  always @(posedge CLK)
  begin
    if(!RST_N)
      OUT_READ <= init;
    else
      if(IN_EN_WRITE)
        OUT_READ <= IN_WRITE;
  end
endmodule

module mkREGU(CLK, RST_N, IN_WRITE, OUT_READ, IN_EN_WRITE);
  parameter width = 1;
  input [((width == 0)? 0: width-1):0] IN_WRITE;
  output reg [((width == 0)? 0: width-1):0] OUT_READ;
  input IN_EN_WRITE, CLK, RST_N;

  initial
    OUT_READ = {((width+1))/2{2'b10}};

  always @(posedge CLK)
    if(IN_EN_WRITE)
      OUT_READ <= IN_WRITE;
endmodule
module mkRand32(CLK, REQ_WRITE, RESP_READ);
  parameter seed = 0;

  input CLK;
  input REQ_WRITE;
  output reg [31:0] RESP_READ;

  integer randomseed;
  initial
  begin
    randomseed = seed;
    RESP_READ = $random(randomseed);
  end

  always @(posedge CLK)
  begin
    if(REQ_WRITE)
      RESP_READ <= $random(randomseed);
  end
endmodule
module mkRegFileVerilogLoad(CLK, RST_N, READ_REQ_WRITE, READ_RESP_READ, WRITE_EN_WRITE, WRITE_INDEX_WRITE, WRITE_DATA_WRITE);
  parameter width = 32;
  parameter n = 5;
  parameter size = 32;
  parameter file = "memory.vmh";
  parameter mode = 0;

  input CLK, RST_N;
  input [((n == 0)? 0: n-1):0] READ_REQ_WRITE;
  output [((width == 0)? 0: width-1):0] READ_RESP_READ;
  input WRITE_EN_WRITE;
  input [((n == 0)? 0: n-1):0] WRITE_INDEX_WRITE;
  input [((width == 0)? 0: width-1):0] WRITE_DATA_WRITE;

  reg [((width == 0)? 0: width-1):0] arr[0:size-1];

  initial
  begin
    if(mode == 1)
      $readmemb(file, arr, 0, size-1);
    else if(mode == 2)
      $readmemh(file, arr, 0, size-1);
  end

  assign READ_RESP_READ = arr[(size == 1)? 0: READ_REQ_WRITE];

  always@(posedge CLK)
  begin
    if(!RST_N)
    begin: allif
      if(mode == 1)
        $readmemb(file, arr, 0, size-1);
      else if(mode ==2)
        $readmemh(file, arr, 0, size-1);
    end
    else if(WRITE_EN_WRITE)
        arr[(size == 1)? 0: WRITE_INDEX_WRITE] <= WRITE_DATA_WRITE;
  end
endmodule
module mkBramVerilog(CLK, RST_N, READ_EN_WRITE, READ_REQ_WRITE, READ_RESP_READ, WRITE_EN_WRITE, WRITE_INDEX_WRITE, WRITE_DATA_WRITE);
  parameter width = 32;
  parameter n = 5;
  parameter size = 32;

  input CLK, RST_N, READ_EN_WRITE;
  input [((n == 0)? 0: n-1):0] READ_REQ_WRITE;
  output [((width == 0)? 0: width-1):0] READ_RESP_READ;
  input WRITE_EN_WRITE;
  input [((n == 0)? 0: n-1):0] WRITE_INDEX_WRITE;
  input [((width == 0)? 0: width-1):0] WRITE_DATA_WRITE;

  reg [((width == 0)? 0: width-1):0] arr[0:size-1];

  reg [((n == 0)? 0: n-1): 0] READ_REQ_WRITE_REG;

  assign READ_RESP_READ = arr[(size == 1)? 0: READ_REQ_WRITE_REG];

  always@(posedge CLK)
  begin
    if(RST_N)
    begin
      if(WRITE_EN_WRITE)
        arr[(size == 1)? 0: WRITE_INDEX_WRITE] <= WRITE_DATA_WRITE;
      READ_REQ_WRITE_REG <= READ_REQ_WRITE;
    end
  end
endmodule
