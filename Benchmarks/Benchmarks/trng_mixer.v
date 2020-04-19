//======================================================================
//
// trng_mixer.v
// ------------
// Mixer for the TRNG.
//
//
// Author: Joachim Strombergson
// Copyright (c) 2014, Secworks Sweden AB
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or
// without modification, are permitted provided that the following
// conditions are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in
//    the documentation and/or other materials provided with the
//    distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module trng_mixer(
                  input wire            clk,
                  input wire            reset_n,

                  input wire            cs,
                  input wire            we,
                  input wire  [7 : 0]   address,
                  input wire  [31 : 0]  write_data,
                  output wire [31 : 0]  read_data,
                  output wire           error,

                  input wire            discard,
                  input wire            test_mode,
                  output wire           security_error,

                  input wire            more_seed,

                  input wire            entropy0_enabled,
                  input wire            entropy0_syn,
                  input wire [31 : 0]   entropy0_data,
                  output wire           entropy0_ack,

                  input wire            entropy1_enabled,
                  input wire            entropy1_syn,
                  input wire [31 : 0]   entropy1_data,
                  output wire           entropy1_ack,

                  input wire            entropy2_enabled,
                  input wire            entropy2_syn,
                  input wire [31 : 0]   entropy2_data,
                  output wire           entropy2_ack,

                  output wire [511 : 0] seed_data,
                  output wire           seed_syn,
                  input wire            seed_ack,

                  output wire [7 : 0]   debug,
                  input wire            debug_update
                 );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter MODE_SHA_512 = 2'h3;

  parameter ENTROPY_IDLE     = 4'h0;
  parameter ENTROPY_SRC0     = 4'h1;
  parameter ENTROPY_SRC0_ACK = 4'h2;
  parameter ENTROPY_SRC1     = 4'h3;
  parameter ENTROPY_SRC1_ACK = 4'h4;
  parameter ENTROPY_SRC2     = 4'h5;
  parameter ENTROPY_SRC2_ACK = 4'h6;

  parameter CTRL_IDLE    = 4'h0;
  parameter CTRL_COLLECT = 4'h1;
  parameter CTRL_MIX     = 4'h2;
  parameter CTRL_SYN     = 4'h3;
  parameter CTRL_ACK     = 4'h4;
  parameter CTRL_NEXT    = 4'h5;

  parameter ADDR_MIXER_CTRL        = 8'h10;
  parameter MIXER_CTRL_ENABLE_BIT  = 0;
  parameter MIXER_CTRL_RESTART_BIT = 1;
  parameter ADDR_MIXER_STATUS      = 8'h11;
  parameter ADDR_MIXER_TIMEOUT     = 8'h20;

  parameter DEFAULT_ENTROPY_TIMEOUT = 24'h100000;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [31 : 0] block00_reg;
  reg          block00_we;
  reg [31 : 0] block01_reg;
  reg          block01_we;
  reg [31 : 0] block02_reg;
  reg          block02_we;
  reg [31 : 0] block03_reg;
  reg          block03_we;
  reg [31 : 0] block04_reg;
  reg          block04_we;
  reg [31 : 0] block05_reg;
  reg          block05_we;
  reg [31 : 0] block06_reg;
  reg          block06_we;
  reg [31 : 0] block07_reg;
  reg          block07_we;
  reg [31 : 0] block08_reg;
  reg          block08_we;
  reg [31 : 0] block09_reg;
  reg          block09_we;
  reg [31 : 0] block10_reg;
  reg          block10_we;
  reg [31 : 0] block11_reg;
  reg          block11_we;
  reg [31 : 0] block12_reg;
  reg          block12_we;
  reg [31 : 0] block13_reg;
  reg          block13_we;
  reg [31 : 0] block14_reg;
  reg          block14_we;
  reg [31 : 0] block15_reg;
  reg          block15_we;
  reg [31 : 0] block16_reg;
  reg          block16_we;
  reg [31 : 0] block17_reg;
  reg          block17_we;
  reg [31 : 0] block18_reg;
  reg          block18_we;
  reg [31 : 0] block19_reg;
  reg          block19_we;
  reg [31 : 0] block20_reg;
  reg          block20_we;
  reg [31 : 0] block21_reg;
  reg          block21_we;
  reg [31 : 0] block22_reg;
  reg          block22_we;
  reg [31 : 0] block23_reg;
  reg          block23_we;
  reg [31 : 0] block24_reg;
  reg          block24_we;
  reg [31 : 0] block25_reg;
  reg          block25_we;
  reg [31 : 0] block26_reg;
  reg          block26_we;
  reg [31 : 0] block27_reg;
  reg          block27_we;
  reg [31 : 0] block28_reg;
  reg          block28_we;
  reg [31 : 0] block29_reg;
  reg          block29_we;
  reg [31 : 0] block30_reg;
  reg          block30_we;
  reg [31 : 0] block31_reg;
  reg          block31_we;

  reg [4 : 0] word_ctr_reg;
  reg [4 : 0] word_ctr_new;
  reg         word_ctr_inc;
  reg         word_ctr_rst;
  reg         word_ctr_we;

  reg [3 : 0] entropy_collect_ctrl_reg;
  reg [3 : 0] entropy_collect_ctrl_new;
  reg         entropy_collect_ctrl_we;

  reg [23 : 0] entropy_timeout_ctr_reg;
  reg [23 : 0] entropy_timeout_ctr_new;
  reg          entropy_timeout_ctr_inc;
  reg          entropy_timeout_ctr_rst;
  reg          entropy_timeout_ctr_we;
  reg          entropy_timeout;

  reg [23 : 0] entropy_timeout_reg;
  reg [23 : 0] entropy_timeout_new;
  reg          entropy_timeout_we;

  reg [3 : 0] mixer_ctrl_reg;
  reg [3 : 0] mixer_ctrl_new;
  reg         mixer_ctrl_we;

  reg         seed_syn_reg;
  reg         seed_syn_new;
  reg         seed_syn_we;

  reg         init_done_reg;
  reg         init_done_new;
  reg         init_done_we;

  reg         enable_reg;
  reg         enable_new;
  reg         enable_we;

  reg         restart_reg;
  reg         restart_new;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0]    muxed_entropy;
  reg             collect_block;
  reg             update_block;
  reg             block_done;

  reg             hash_init;
  reg             hash_next;

  wire            hash_work_factor;
  wire [31 : 0]   hash_work_factor_num;


  wire [1023 : 0] hash_block;
  wire            hash_ready;
  wire [511 : 0]  hash_digest;
  wire            hash_digest_valid;

  reg             tmp_entropy0_ack;
  reg             tmp_entropy1_ack;
  reg             tmp_entropy2_ack;

  reg [31 : 0]    tmp_read_data;
  reg             tmp_error;


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign read_data      = tmp_read_data;
  assign error          = tmp_error;
  assign security_error = 0;

  assign seed_syn  = seed_syn_reg;
  assign seed_data = hash_digest;

  assign hash_block = {block00_reg, block01_reg, block02_reg, block03_reg,
                       block04_reg, block05_reg, block06_reg, block07_reg,
                       block08_reg, block09_reg,
                       block10_reg, block11_reg, block12_reg, block13_reg,
                       block14_reg, block15_reg, block16_reg, block17_reg,
                       block18_reg, block19_reg,
                       block20_reg, block21_reg, block22_reg, block23_reg,
                       block24_reg, block25_reg, block26_reg, block27_reg,
                       block28_reg, block29_reg,
                       block30_reg, block31_reg};

  assign hash_work_factor     = 0;
  assign hash_work_factor_num = 32'h00000000;

  assign entropy0_ack = tmp_entropy0_ack;
  assign entropy1_ack = tmp_entropy1_ack;
  assign entropy2_ack = tmp_entropy2_ack;

  assign debug = 8'h55;


  //----------------------------------------------------------------
  // core instantiation.
  //----------------------------------------------------------------
  sha512_core hash_inst(
                        .clk(clk),
                        .reset_n(reset_n),

                        .init(hash_init),
                        .next(hash_next),
                        .mode(MODE_SHA_512),

                        .work_factor(hash_work_factor),
                        .work_factor_num(hash_work_factor_num),

                        .block(hash_block),

                        .ready(hash_ready),
                        .digest(hash_digest),
                        .digest_valid(hash_digest_valid)
                       );


  //----------------------------------------------------------------
  // reg_update
  //
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with asynchronous
  // active low reset.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin
      if (!reset_n)
        begin
          block00_reg              <= 32'h00000000;
          block01_reg              <= 32'h00000000;
          block02_reg              <= 32'h00000000;
          block03_reg              <= 32'h00000000;
          block04_reg              <= 32'h00000000;
          block05_reg              <= 32'h00000000;
          block06_reg              <= 32'h00000000;
          block07_reg              <= 32'h00000000;
          block08_reg              <= 32'h00000000;
          block09_reg              <= 32'h00000000;
          block10_reg              <= 32'h00000000;
          block11_reg              <= 32'h00000000;
          block12_reg              <= 32'h00000000;
          block13_reg              <= 32'h00000000;
          block14_reg              <= 32'h00000000;
          block15_reg              <= 32'h00000000;
          block16_reg              <= 32'h00000000;
          block17_reg              <= 32'h00000000;
          block18_reg              <= 32'h00000000;
          block19_reg              <= 32'h00000000;
          block20_reg              <= 32'h00000000;
          block21_reg              <= 32'h00000000;
          block22_reg              <= 32'h00000000;
          block23_reg              <= 32'h00000000;
          block24_reg              <= 32'h00000000;
          block25_reg              <= 32'h00000000;
          block26_reg              <= 32'h00000000;
          block27_reg              <= 32'h00000000;
          block28_reg              <= 32'h00000000;
          block29_reg              <= 32'h00000000;
          block30_reg              <= 32'h00000000;
          block31_reg              <= 32'h00000000;
          init_done_reg            <= 0;
          word_ctr_reg             <= 5'h00;
          seed_syn_reg             <= 0;
          enable_reg               <= 1;
          restart_reg              <= 0;
          entropy_timeout_reg      <= DEFAULT_ENTROPY_TIMEOUT;
          entropy_timeout_ctr_reg  <= 24'h000000;
          entropy_collect_ctrl_reg <= CTRL_IDLE;
          mixer_ctrl_reg           <= CTRL_IDLE;
        end
      else
        begin
          restart_reg <= restart_new;

          if (block00_we)
            begin
              block00_reg <= muxed_entropy;
            end

          if (block01_we)
            begin
              block01_reg <= muxed_entropy;
            end

          if (block02_we)
            begin
              block02_reg <= muxed_entropy;
            end

          if (block03_we)
            begin
              block03_reg <= muxed_entropy;
            end

          if (block04_we)
            begin
              block04_reg <= muxed_entropy;
            end

          if (block05_we)
            begin
              block05_reg <= muxed_entropy;
            end

          if (block06_we)
            begin
              block06_reg <= muxed_entropy;
            end

          if (block07_we)
            begin
              block07_reg <= muxed_entropy;
            end

          if (block08_we)
            begin
              block08_reg <= muxed_entropy;
            end

          if (block09_we)
            begin
              block09_reg <= muxed_entropy;
            end

          if (block10_we)
            begin
              block10_reg <= muxed_entropy;
            end

          if (block11_we)
            begin
              block11_reg <= muxed_entropy;
            end

          if (block12_we)
            begin
              block12_reg <= muxed_entropy;
            end

          if (block13_we)
            begin
              block13_reg <= muxed_entropy;
            end

          if (block14_we)
            begin
              block14_reg <= muxed_entropy;
            end

          if (block15_we)
            begin
              block15_reg <= muxed_entropy;
            end

          if (block16_we)
            begin
              block16_reg <= muxed_entropy;
            end

          if (block17_we)
            begin
              block17_reg <= muxed_entropy;
            end

          if (block18_we)
            begin
              block18_reg <= muxed_entropy;
            end

          if (block19_we)
            begin
              block19_reg <= muxed_entropy;
            end

          if (block20_we)
            begin
              block20_reg <= muxed_entropy;
            end

          if (block21_we)
            begin
              block21_reg <= muxed_entropy;
            end

          if (block22_we)
            begin
              block22_reg <= muxed_entropy;
            end

          if (block23_we)
            begin
              block23_reg <= muxed_entropy;
            end

          if (block24_we)
            begin
              block24_reg <= muxed_entropy;
            end

          if (block25_we)
            begin
              block25_reg <= muxed_entropy;
            end

          if (block26_we)
            begin
              block26_reg <= muxed_entropy;
            end

          if (block27_we)
            begin
              block27_reg <= muxed_entropy;
            end

          if (block28_we)
            begin
              block28_reg <= muxed_entropy;
            end

          if (block29_we)
            begin
              block29_reg <= muxed_entropy;
            end

          if (block30_we)
            begin
              block30_reg <= muxed_entropy;
            end

          if (block31_we)
            begin
              block31_reg <= muxed_entropy;
            end

          if (init_done_we)
            begin
              init_done_reg <= init_done_new;
            end

          if (word_ctr_we)
            begin
              word_ctr_reg <= word_ctr_new;
            end

          if (seed_syn_we)
            begin
              seed_syn_reg <= seed_syn_new;
            end

          if (entropy_collect_ctrl_we)
            begin
              entropy_collect_ctrl_reg <= entropy_collect_ctrl_new;
            end

          if (enable_we)
            begin
              enable_reg <= enable_new;
            end

          if (mixer_ctrl_we)
            begin
              mixer_ctrl_reg <= mixer_ctrl_new;
            end

          if (entropy_timeout_we)
            begin
              entropy_timeout_reg <= entropy_timeout_new;
            end

          if (entropy_timeout_ctr_we)
            begin
              entropy_timeout_ctr_reg <= entropy_timeout_ctr_new;
            end
        end
    end // reg_update


  //----------------------------------------------------------------
  // mixer_api_logic
  //----------------------------------------------------------------
  always @*
    begin : mixer_api_logic
      enable_new          = 0;
      enable_we           = 0;
      restart_reg         = 0;
      restart_new         = 0;
      entropy_timeout_new = 24'h000000;
      entropy_timeout_we  = 0;
      tmp_read_data       = 32'h00000000;
      tmp_error           = 0;

      if (cs)
        begin
          if (we)
            begin
              // Write operations.
              case (address)
                // Write operations.
                ADDR_MIXER_CTRL:
                  begin
                    enable_new  = write_data[MIXER_CTRL_ENABLE_BIT];
                    enable_we   = 1;
                    restart_new = write_data[MIXER_CTRL_RESTART_BIT];
                  end

                ADDR_MIXER_TIMEOUT:
                  begin
                    entropy_timeout_new = write_data[23 : 0];
                    entropy_timeout_we  = 1;
                  end

                default:
                  begin
                    tmp_error = 1;
                  end
              endcase // case (address)
            end // if (we)

          else
            begin
              // Read operations.
              case (address)
                // Read operations.
                ADDR_MIXER_CTRL:
                  begin
                    tmp_read_data = {30'h00000000, restart_reg, enable_reg};
                  end

                ADDR_MIXER_STATUS:
                  begin
                    tmp_read_data = 32'h00000000;
                  end

                ADDR_MIXER_TIMEOUT:
                  begin
                    tmp_read_data = {8'h00, entropy_timeout_reg};
                  end

                default:
                  begin
                    tmp_error = 1;
                  end
              endcase // case (address)
            end
        end
    end // mixer_api_logic


  //----------------------------------------------------------------
  // entropy_collect_ctrl
  //
  // This FSM implements a round-robin mux for signals from the
  // entropy sources and updates the block until a block has
  // been filled.
  //----------------------------------------------------------------
  always @*
    begin : entropy_mux
      tmp_entropy0_ack         = 0;
      tmp_entropy1_ack         = 0;
      tmp_entropy2_ack         = 0;
      word_ctr_inc             = 0;
      word_ctr_rst             = 0;
      update_block             = 0;
      block_done               = 0;
      muxed_entropy            = 32'h00000000;
      entropy_timeout_ctr_inc  = 0;
      entropy_timeout_ctr_rst  = 0;
      entropy_collect_ctrl_new = ENTROPY_IDLE;
      entropy_collect_ctrl_we  = 0;

      case (entropy_collect_ctrl_reg)
        ENTROPY_IDLE:
          begin
            if (collect_block)
              begin
                word_ctr_rst             = 1;
                entropy_timeout_ctr_rst  = 1;
                entropy_collect_ctrl_new = ENTROPY_SRC0;
                entropy_collect_ctrl_we  = 1;
              end
          end

        ENTROPY_SRC0:
          begin
            if (!enable_reg)
              begin
                word_ctr_rst             = 1;
                entropy_collect_ctrl_new = ENTROPY_IDLE;
                entropy_collect_ctrl_we  = 1;
              end
            else
              begin
                if (entropy0_enabled)
                  begin
                    if (entropy0_syn)
                      begin
                        muxed_entropy            = entropy0_data;
                        update_block             = 1;
                        entropy_collect_ctrl_new = ENTROPY_SRC0_ACK;
                        entropy_collect_ctrl_we  = 1;
                      end
                    else
                      if (entropy_timeout)
                        begin
                          entropy_timeout_ctr_rst  = 1;
                          entropy_collect_ctrl_new = ENTROPY_SRC1;
                          entropy_collect_ctrl_we  = 1;
                        end
                      else
                        begin
                          entropy_timeout_ctr_inc = 1;
                        end
                  end
                else
                  begin
                    entropy_timeout_ctr_rst  = 1;
                    entropy_collect_ctrl_new = ENTROPY_SRC1;
                    entropy_collect_ctrl_we  = 1;
                  end
              end
          end

        ENTROPY_SRC0_ACK:
          begin
            tmp_entropy0_ack = 1;
            if (!enable_reg)
              begin
                word_ctr_rst             = 1;
                entropy_collect_ctrl_new = ENTROPY_IDLE;
                entropy_collect_ctrl_we  = 1;
              end
            else
              begin
                if (word_ctr_reg == 5'h1f)
                  begin
                    block_done               = 1;
                    entropy_collect_ctrl_new = ENTROPY_IDLE;
                    entropy_collect_ctrl_we  = 1;
                  end
                else
                  begin
                    word_ctr_inc             = 1;
                    entropy_collect_ctrl_new = ENTROPY_SRC1;
                    entropy_collect_ctrl_we  = 1;
                  end
              end
          end


        ENTROPY_SRC1:
          begin
            if (!enable_reg)
              begin
                word_ctr_rst             = 1;
                entropy_collect_ctrl_new = ENTROPY_IDLE;
                entropy_collect_ctrl_we  = 1;
              end
            else
              begin
                if (entropy1_enabled)
                  begin
                    if (entropy1_syn)
                      begin
                        muxed_entropy            = entropy1_data;
                        update_block             = 1;
                        entropy_collect_ctrl_new = ENTROPY_SRC1_ACK;
                        entropy_collect_ctrl_we  = 1;
                      end
                    else
                      if (entropy_timeout)
                        begin
                          entropy_timeout_ctr_rst  = 1;
                          entropy_collect_ctrl_new = ENTROPY_SRC2;
                          entropy_collect_ctrl_we  = 1;
                        end
                      else
                        begin
                          entropy_timeout_ctr_inc = 1;
                        end
                  end
                else
                  begin
                    entropy_collect_ctrl_new = ENTROPY_SRC2;
                    entropy_collect_ctrl_we  = 1;
                  end
              end
          end

        ENTROPY_SRC1_ACK:
          begin
            tmp_entropy1_ack = 1;
            if (!enable_reg)
              begin
                word_ctr_rst             = 1;
                entropy_collect_ctrl_new = ENTROPY_IDLE;
                entropy_collect_ctrl_we  = 1;
              end
            else
              begin
                if (word_ctr_reg == 5'h1f)
                  begin
                    block_done               = 1;
                    entropy_collect_ctrl_new = ENTROPY_IDLE;
                    entropy_collect_ctrl_we  = 1;
                  end
                else
                  begin
                    word_ctr_inc             = 1;
                    entropy_collect_ctrl_new = ENTROPY_SRC2;
                    entropy_collect_ctrl_we  = 1;
                  end
              end
          end

        ENTROPY_SRC2:
          begin
            if (!enable_reg)
              begin
                word_ctr_rst             = 1;
                entropy_collect_ctrl_new = ENTROPY_IDLE;
                entropy_collect_ctrl_we  = 1;
              end
            else
              begin
                if (entropy2_enabled)
                  begin
                    if (entropy2_syn)
                      begin
                        muxed_entropy            = entropy2_data;
                        update_block             = 1;
                        entropy_collect_ctrl_new = ENTROPY_SRC2_ACK;
                        entropy_collect_ctrl_we  = 1;
                      end
                    else
                      if (entropy_timeout)
                        begin
                          entropy_timeout_ctr_rst  = 1;
                          entropy_collect_ctrl_new = ENTROPY_SRC0;
                          entropy_collect_ctrl_we  = 1;
                        end
                      else
                        begin
                          entropy_timeout_ctr_inc = 1;
                        end
                  end
                else
                  begin
                    entropy_collect_ctrl_new = ENTROPY_SRC0;
                    entropy_collect_ctrl_we  = 1;
                  end
              end
          end

        ENTROPY_SRC2_ACK:
          begin
            tmp_entropy2_ack = 1;
            if (!enable_reg)
              begin
                word_ctr_rst             = 1;
                entropy_collect_ctrl_new = ENTROPY_IDLE;
                entropy_collect_ctrl_we  = 1;
              end
            else
              begin
                if (word_ctr_reg == 5'h1f)
                  begin
                    block_done               = 1;
                    entropy_collect_ctrl_new = ENTROPY_IDLE;
                    entropy_collect_ctrl_we  = 1;
                  end
                else
                  begin
                    word_ctr_inc             = 1;
                    entropy_collect_ctrl_new = ENTROPY_SRC0;
                    entropy_collect_ctrl_we  = 1;
                  end
              end
          end

      endcase // case (entropy_collect_ctrl_reg)
    end // entropy_mux


  //----------------------------------------------------------------
  // word_mux
  //----------------------------------------------------------------
  always @*
    begin : word_mux
      block00_we = 0;
      block01_we = 0;
      block02_we = 0;
      block03_we = 0;
      block04_we = 0;
      block05_we = 0;
      block06_we = 0;
      block07_we = 0;
      block08_we = 0;
      block09_we = 0;
      block10_we = 0;
      block11_we = 0;
      block12_we = 0;
      block13_we = 0;
      block14_we = 0;
      block15_we = 0;
      block16_we = 0;
      block17_we = 0;
      block18_we = 0;
      block19_we = 0;
      block20_we = 0;
      block21_we = 0;
      block22_we = 0;
      block23_we = 0;
      block24_we = 0;
      block25_we = 0;
      block26_we = 0;
      block27_we = 0;
      block28_we = 0;
      block29_we = 0;
      block30_we = 0;
      block31_we = 0;

      if (update_block)
        begin
          case (word_ctr_reg)
            00 : block00_we = 1;
            01 : block01_we = 1;
            02 : block02_we = 1;
            03 : block03_we = 1;
            04 : block04_we = 1;
            05 : block05_we = 1;
            06 : block06_we = 1;
            07 : block07_we = 1;
            08 : block08_we = 1;
            09 : block09_we = 1;
            10 : block10_we = 1;
            11 : block11_we = 1;
            12 : block12_we = 1;
            13 : block13_we = 1;
            14 : block14_we = 1;
            15 : block15_we = 1;
            16 : block16_we = 1;
            17 : block17_we = 1;
            18 : block18_we = 1;
            19 : block19_we = 1;
            20 : block20_we = 1;
            21 : block21_we = 1;
            22 : block22_we = 1;
            23 : block23_we = 1;
            24 : block24_we = 1;
            25 : block25_we = 1;
            26 : block26_we = 1;
            27 : block27_we = 1;
            28 : block28_we = 1;
            29 : block29_we = 1;
            30 : block30_we = 1;
            31 : block31_we = 1;
          endcase // case (word_ctr_reg)
        end
    end // word_mux


  //----------------------------------------------------------------
  // entropy_timeout_logic
  //
  // Logic that updates the entropy timeout counter and signals
  // when the wait for antropy from a provider has exceeded
  // acceptable time.
  //----------------------------------------------------------------
  always @*
    begin : entropy_timeout_logic
      entropy_timeout_ctr_new = 24'h000000;
      entropy_timeout_ctr_we  = 0;
      entropy_timeout         = 0;

      if (entropy_timeout_ctr_reg == entropy_timeout_reg)
        begin
          entropy_timeout         = 1;
          entropy_timeout_ctr_new = 24'h000000;
          entropy_timeout_ctr_we  = 1;
        end

      if (entropy_timeout_ctr_rst)
        begin
          entropy_timeout_ctr_new = 24'h000000;
          entropy_timeout_ctr_we  = 1;
        end

      if (entropy_timeout_ctr_inc)
        begin
          entropy_timeout_ctr_new = entropy_timeout_ctr_reg + 1'b1;
          entropy_timeout_ctr_we  = 1;
        end
    end


  //----------------------------------------------------------------
  // word_ctr
  //----------------------------------------------------------------
  always @*
    begin : word_ctr
      word_ctr_new = 5'h00;
      word_ctr_we  = 0;

      if (word_ctr_rst)
        begin
          word_ctr_new = 5'h00;
          word_ctr_we  = 1;
        end

      if (word_ctr_inc)
        begin
          word_ctr_new = word_ctr_reg + 1'b1;
          word_ctr_we  = 1;
        end
    end // word_ctr


  //----------------------------------------------------------------
  // mixer_ctrl_fsm
  //
  // Control FSM for the mixer.
  //----------------------------------------------------------------
  always @*
    begin : mixer_ctrl_fsm
      seed_syn_new   = 0;
      seed_syn_we    = 0;
      init_done_new  = 0;
      init_done_we   = 0;
      hash_init      = 0;
      hash_next      = 0;
      collect_block  = 0;
      mixer_ctrl_new = CTRL_IDLE;
      mixer_ctrl_we  = 0;

      case (mixer_ctrl_reg)
        CTRL_IDLE:
          begin
            if (more_seed)
              begin
                collect_block  = 1;
                init_done_new  = 0;
                init_done_we   = 1;
                mixer_ctrl_new = CTRL_COLLECT;
                mixer_ctrl_we  = 1;
              end
          end

        CTRL_COLLECT:
          begin
            if ((discard))
              begin
                mixer_ctrl_new = CTRL_IDLE;
                mixer_ctrl_we  = 1;
              end
            else
              begin
                if (block_done)
                  begin
                    mixer_ctrl_new = CTRL_MIX;
                    mixer_ctrl_we  = 1;
                  end
              end
          end

        CTRL_MIX:
          begin
            if ((discard))
              begin
                mixer_ctrl_new = CTRL_IDLE;
                mixer_ctrl_we  = 1;
              end
            else
              begin
                if (init_done_reg)
                  begin
                    hash_next = 1;
                  end
                else
                  begin
                    hash_init = 1;
                  end
                mixer_ctrl_new = CTRL_SYN;
                mixer_ctrl_we  = 1;
              end
          end

        CTRL_SYN:
          begin
            if ((discard))
              begin
                mixer_ctrl_new = CTRL_IDLE;
                mixer_ctrl_we  = 1;
              end
            else if (hash_ready)
              begin
                seed_syn_new   = 1;
                seed_syn_we    = 1;
                mixer_ctrl_new = CTRL_ACK;
                mixer_ctrl_we  = 1;
              end

          end

        CTRL_ACK:
          begin
            if ((discard))
              begin
                mixer_ctrl_new = CTRL_IDLE;
                mixer_ctrl_we  = 1;
              end
            else if (seed_ack)
              begin
                seed_syn_new   = 0;
                seed_syn_we    = 1;
                mixer_ctrl_new = CTRL_NEXT;
                mixer_ctrl_we  = 1;
              end
          end

        CTRL_NEXT:
          begin
            if ((discard))
              begin
                mixer_ctrl_new = CTRL_IDLE;
                mixer_ctrl_we  = 1;
              end
            else if (more_seed)
              begin
                collect_block  = 1;
                init_done_new  = 1;
                init_done_we   = 1;
                mixer_ctrl_new = CTRL_COLLECT;
                mixer_ctrl_we  = 1;
              end
          end

      endcase // case (cspng_ctrl_reg)
    end // mixer_ctrl_fsm

endmodule // trng_mixer

//======================================================================
// EOF trng_mixer.v
//======================================================================
