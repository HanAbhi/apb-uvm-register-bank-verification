// APB4-style register bank reference DUT.
// BUG_MODE=0: correct design
// BUG_MODE=1: SCRATCH address decode defect
// BUG_MODE=2: RO protection defect
// BUG_MODE=3: W1C polarity defect
module apb_regbank #(
  parameter int WAIT_STATES = 2,
  parameter int BUG_MODE = 0
)(
  input  logic        PCLK, PRESETn,
  input  logic        PSEL, PENABLE, PWRITE,
  input  logic [7:0]  PADDR,
  input  logic [31:0] PWDATA,
  input  logic [3:0]  PSTRB,
  output logic [31:0] PRDATA,
  output logic        PREADY, PSLVERR
);
  logic [31:0] ctrl, int_status, scratch;
  logic [31:0] status_reg;
  int unsigned wait_count;
  logic access, complete;
  logic [7:0] decode_addr;

  assign access = PSEL && PENABLE;
  assign PREADY = access && (wait_count >= WAIT_STATES);
  assign complete = access && PREADY;
  assign status_reg = 32'h0000_0001;
  assign decode_addr = (BUG_MODE == 1 && PADDR == 8'h0C) ? 8'h10 : PADDR;

  always_comb begin
    PRDATA = 32'h0;
    PSLVERR = 1'b0;
    if (access) begin
      case (decode_addr)
        8'h00: PRDATA = ctrl;
        8'h04: PRDATA = status_reg;
        8'h08: PRDATA = int_status;
        8'h0C: PRDATA = scratch;
        default: begin PRDATA = 32'h0; PSLVERR = 1'b1; end
      endcase
      if (PWRITE && PADDR == 8'h04 && BUG_MODE != 2)
        PSLVERR = 1'b1;
    end
  end

  always_ff @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn) begin
      ctrl <= 0;
      int_status <= 32'h0000_000F;
      scratch <= 0;
      wait_count <= 0;
    end else begin
      if (!access || PREADY) wait_count <= 0;
      else wait_count <= wait_count + 1;

      if (complete && PWRITE && !PSLVERR) begin
        case (decode_addr)
          8'h00: begin
            for (int i=0; i<4; i++)
              if (PSTRB[i]) ctrl[i*8 +: 8] <= PWDATA[i*8 +: 8];
          end
          8'h04: if (BUG_MODE == 2) begin
            // Deliberate bug: RO register is writable.
          end
          8'h08: begin
            if (BUG_MODE == 3) int_status <= int_status & PWDATA; // wrong polarity
            else               int_status <= int_status & ~PWDATA; // W1C
          end
          8'h0C: begin
            for (int i=0; i<4; i++)
              if (PSTRB[i]) scratch[i*8 +: 8] <= PWDATA[i*8 +: 8];
          end
          default: ;
        endcase
      end
    end
  end
endmodule
