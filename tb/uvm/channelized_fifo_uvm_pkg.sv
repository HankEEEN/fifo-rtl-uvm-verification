`timescale 1ns/1ps
`default_nettype none

package channelized_fifo_uvm_pkg;
    import uvm_pkg::*;
    import channelized_fifo_uvm_cfg_pkg::*;
    `include "uvm_macros.svh"

    typedef logic [DATA_W*CHANS-1:0] fifo_word_t;

    class fifo_write_item extends uvm_sequence_item;
        bit winc;
        bit block_winc;
        bit clear_wr;
        logic [CHANS-1:0] write_mask;
        logic [CHANS-1:0] clear_chan;
        fifo_word_t data;

        `uvm_object_utils(fifo_write_item)

        function new(string name = "fifo_write_item");
            super.new(name);
        endfunction
    endclass

    class fifo_read_item extends uvm_sequence_item;
        bit rinc;
        bit block_rinc;
        bit clear_rd;
        logic [CHANS-1:0] clear_chan;

        `uvm_object_utils(fifo_read_item)

        function new(string name = "fifo_read_item");
            super.new(name);
        endfunction
    endclass

    class fifo_write_sequence extends uvm_sequence #(fifo_write_item);
        fifo_write_item command;
        `uvm_object_utils(fifo_write_sequence)

        function new(string name = "fifo_write_sequence");
            super.new(name);
            command = fifo_write_item::type_id::create("command");
        endfunction

        task body();
            start_item(command);
            finish_item(command);
        endtask
    endclass

    class fifo_read_sequence extends uvm_sequence #(fifo_read_item);
        fifo_read_item command;
        `uvm_object_utils(fifo_read_sequence)

        function new(string name = "fifo_read_sequence");
            super.new(name);
            command = fifo_read_item::type_id::create("command");
        endfunction

        task body();
            start_item(command);
            finish_item(command);
        endtask
    endclass

    class fifo_write_sequencer extends uvm_sequencer #(fifo_write_item);
        `uvm_component_utils(fifo_write_sequencer)
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class fifo_read_sequencer extends uvm_sequencer #(fifo_read_item);
        `uvm_component_utils(fifo_read_sequencer)
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class fifo_write_driver extends uvm_driver #(fifo_write_item);
        `uvm_component_utils(fifo_write_driver)
        virtual channelized_fifo_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual channelized_fifo_if)::get(
                    this, "", "vif", vif))
                `uvm_fatal("NOVIF", "write driver did not receive vif")
        endfunction

        task drive_idle();
            vif.winc          <= 1'b0;
            vif.block_winc    <= 1'b0;
            vif.clear_wr      <= 1'b0;
            vif.write         <= '0;
            vif.clear_chan_wr <= '0;
            vif.din           <= '0;
        endtask

        task run_phase(uvm_phase phase);
            fifo_write_item req;
            drive_idle();
            forever begin
                @(negedge vif.clk_wr);
                req = null;
                seq_item_port.try_next_item(req);
                if (req == null) begin
                    drive_idle();
                end else begin
                    vif.winc          <= req.winc;
                    vif.block_winc    <= req.block_winc;
                    vif.clear_wr      <= req.clear_wr;
                    vif.write         <= req.write_mask;
                    vif.clear_chan_wr <= req.clear_chan;
                    vif.din           <= req.data;
                    seq_item_port.item_done();
                end
            end
        endtask
    endclass

    class fifo_read_driver extends uvm_driver #(fifo_read_item);
        `uvm_component_utils(fifo_read_driver)
        virtual channelized_fifo_if vif;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual channelized_fifo_if)::get(
                    this, "", "vif", vif))
                `uvm_fatal("NOVIF", "read driver did not receive vif")
        endfunction

        task drive_idle();
            vif.rinc          <= 1'b0;
            vif.block_rinc    <= 1'b0;
            vif.clear_rd      <= 1'b0;
            vif.clear_chan_rd <= '0;
        endtask

        task run_phase(uvm_phase phase);
            fifo_read_item req;
            drive_idle();
            forever begin
                @(negedge vif.clk_rd);
                req = null;
                seq_item_port.try_next_item(req);
                if (req == null) begin
                    drive_idle();
                end else begin
                    vif.rinc          <= req.rinc;
                    vif.block_rinc    <= req.block_rinc;
                    vif.clear_rd      <= req.clear_rd;
                    vif.clear_chan_rd <= req.clear_chan;
                    seq_item_port.item_done();
                end
            end
        endtask
    endclass

    class fifo_write_agent extends uvm_agent;
        `uvm_component_utils(fifo_write_agent)
        fifo_write_sequencer sequencer;
        fifo_write_driver driver;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer = fifo_write_sequencer::type_id::create("sequencer", this);
            driver = fifo_write_driver::type_id::create("driver", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
        endfunction
    endclass

    class fifo_read_agent extends uvm_agent;
        `uvm_component_utils(fifo_read_agent)
        fifo_read_sequencer sequencer;
        fifo_read_driver driver;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer = fifo_read_sequencer::type_id::create("sequencer", this);
            driver = fifo_read_driver::type_id::create("driver", this);
        endfunction

        function void connect_phase(uvm_phase phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
        endfunction
    endclass

    // This passive scoreboard samples the interface itself.  Keeping the two
    // clock-domain samplers in one component lets synchronous same-edge read
    // and write behavior be modeled atomically.
    class fifo_scoreboard extends uvm_component;
        `uvm_component_utils(fifo_scoreboard)
        virtual channelized_fifo_if vif;
        logic [DATA_W-1:0] model_mem [0:LENGTH-1][0:CHANS-1];
        fifo_word_t expected_q[$];
        logic [PTR_W:0] model_wptr;
        logic [PTR_W:0] model_rptr;
        fifo_word_t model_dout;
        int unsigned writes_accepted;
        int unsigned reads_accepted;
        int unsigned overflow_seen;
        int unsigned underflow_source_seen;
        int unsigned underflow_dest_seen;
        int unsigned blocked_seen;
        int unsigned lane_clear_seen;
        int unsigned wraps_seen;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual channelized_fifo_if)::get(
                    this, "", "vif", vif))
                `uvm_fatal("NOVIF", "scoreboard did not receive vif")
            reset_model(1'b1);
        endfunction

        function logic [PTR_W:0] increment_pointer(logic [PTR_W:0] ptr);
            logic [PTR_W:0] result;
            result = ptr;
            if (LENGTH == 1)
                result = {~ptr[PTR_W], {PTR_W{1'b0}}};
            else if (ptr[PTR_W-1:0] == PTR_W'(LENGTH-1))
                result = {~ptr[PTR_W], {PTR_W{1'b0}}};
            else
                result = ptr + {{PTR_W{1'b0}}, 1'b1};
            return result;
        endfunction

        function void reset_model(bit reset_memory);
            int address;
            int channel;
            expected_q.delete();
            model_wptr = PTR_DEF;
            model_rptr = PTR_DEF;
            model_dout = {CHANS{MEM_RST_VAL}};
            if (reset_memory)
                for (address = 0; address < LENGTH; address++)
                    for (channel = 0; channel < CHANS; channel++)
                        model_mem[address][channel] = MEM_RST_VAL;
        endfunction

        function fifo_word_t memory_word(int unsigned address);
            fifo_word_t result;
            int channel;
            result = '0;
            for (channel = 0; channel < CHANS; channel++)
                result[channel*DATA_W +: DATA_W] =
                    model_mem[address][channel];
            return result;
        endfunction

        function void update_queued_lane(int channel, logic [DATA_W-1:0] value);
            int index;
            for (index = 0; index < expected_q.size(); index++)
                expected_q[index][channel*DATA_W +: DATA_W] = value;
        endfunction

        task process_sync_edge();
            bit pre_full;
            bit pre_empty;
            bit push;
            bit pop;
            bit can_write;
            bit do_read;
            bit [CHANS-1:0] valid_lanes;
            logic [CHANS-1:0] clear_wr_lanes;
            logic [CHANS-1:0] clear_rd_lanes;
            fifo_word_t input_data;
            fifo_word_t read_value;
            int read_address;
            int old_size;
            int channel;

            pre_full = vif.full;
            pre_empty = vif.empty;
            clear_wr_lanes = vif.clear_chan_wr;
            clear_rd_lanes = vif.clear_chan_rd;
            input_data = vif.din;
            pop = vif.rinc && !vif.block_rinc && !vif.clear_rd && !pre_empty;
            can_write = !pre_full || (LOW_LATENCY && pop);
            push = vif.winc && !vif.block_winc && !vif.clear_wr && can_write;
            valid_lanes = vif.write & {CHANS{can_write && !vif.clear_wr}};
            old_size = expected_q.size();
            do_read = pop;
            read_address = model_rptr[PTR_W-1:0];
            if (LOW_LATENCY) begin
                if (pop && (old_size > 1)) begin
                    do_read = 1'b1;
                    begin
                        logic [PTR_W:0] next_read_pointer;
                        next_read_pointer = increment_pointer(model_rptr);
                        read_address = next_read_pointer[PTR_W-1:0];
                    end
                end else if (push && (pre_empty || pop)) begin
                    do_read = 1'b1;
                    read_address = model_wptr[PTR_W-1:0];
                end else begin
                    do_read = 1'b0;
                end
            end

            read_value = model_dout;
            if (do_read)
                read_value = memory_word(read_address);
            for (channel = 0; channel < CHANS; channel++) begin
                if (clear_rd_lanes[channel])
                    read_value[channel*DATA_W +: DATA_W] = MEM_RST_VAL;
                else if (do_read && LOW_LATENCY && clear_wr_lanes[channel])
                    read_value[channel*DATA_W +: DATA_W] = MEM_RST_VAL;
                else if (do_read && LOW_LATENCY && valid_lanes[channel] &&
                         (model_wptr[PTR_W-1:0] == PTR_W'(read_address)))
                    read_value[channel*DATA_W +: DATA_W] =
                        input_data[channel*DATA_W +: DATA_W];
            end

            #1ps;
            if (!vif.rst_wr_an || !vif.rst_rd_an) begin
                reset_model(1'b1);
                return;
            end

            if (vif.clear_wr || vif.clear_rd) begin
                reset_model(1'b0);
            end else begin
                for (channel = 0; channel < CHANS; channel++) begin
                    if (clear_wr_lanes[channel]) begin
                        int address;
                        lane_clear_seen++;
                        for (address = 0; address < LENGTH; address++)
                            model_mem[address][channel] = MEM_RST_VAL;
                        update_queued_lane(channel, MEM_RST_VAL);
                    end else if (valid_lanes[channel]) begin
                        model_mem[model_wptr[PTR_W-1:0]][channel] =
                            input_data[channel*DATA_W +: DATA_W];
                    end
                end

                if (pop) begin
                    if (expected_q.size() == 0)
                        `uvm_error("SCOREBOARD", "accepted read with empty model queue")
                    else
                        void'(expected_q.pop_front());
                    if (model_rptr[PTR_W-1:0] == PTR_W'(LENGTH-1))
                        wraps_seen++;
                    model_rptr = increment_pointer(model_rptr);
                    reads_accepted++;
                end
                if (push) begin
                    expected_q.push_back(memory_word(model_wptr[PTR_W-1:0]));
                    if (model_wptr[PTR_W-1:0] == PTR_W'(LENGTH-1))
                        wraps_seen++;
                    model_wptr = increment_pointer(model_wptr);
                    writes_accepted++;
                end
            end

            if (do_read || (clear_rd_lanes != '0)) begin
                model_dout = read_value;
                if (vif.dout !== model_dout)
                    `uvm_error("DATA", $sformatf(
                        "dout mismatch: actual=0x%0h expected=0x%0h at %0t",
                        vif.dout, model_dout, $time))
            end

            if (vif.wr_ptr_bin !== model_wptr)
                `uvm_error("POINTER", $sformatf(
                    "write pointer actual=%0d expected=%0d", vif.wr_ptr_bin,
                    model_wptr))
            if (vif.rd_ptr_bin !== model_rptr)
                `uvm_error("POINTER", $sformatf(
                    "read pointer actual=%0d expected=%0d", vif.rd_ptr_bin,
                    model_rptr))
            if (vif.how_full_wr !== (PTR_W+1)'(expected_q.size()))
                `uvm_error("OCCUPANCY", $sformatf(
                    "write occupancy actual=%0d expected=%0d",
                    vif.how_full_wr, expected_q.size()))
            if (vif.how_full_rd !== (PTR_W+1)'(expected_q.size()))
                `uvm_error("OCCUPANCY", $sformatf(
                    "read occupancy actual=%0d expected=%0d",
                    vif.how_full_rd, expected_q.size()))
            if (vif.overflow !==
                (vif.winc && !vif.block_winc && !can_write))
                `uvm_error("OVERFLOW", "overflow pulse mismatch")
            if (vif.underflow !==
                (vif.rinc && !vif.block_rinc && !vif.clear_rd && pre_empty))
                `uvm_error("UNDERFLOW", "underflow pulse mismatch")

            if (vif.overflow) overflow_seen++;
            if (vif.underflow) begin
                underflow_source_seen++;
                underflow_dest_seen++;
            end
            if (vif.block_winc || vif.block_rinc) blocked_seen++;
        endtask

        task process_async_write_edge();
            bit pre_full;
            bit can_write;
            bit push;
            bit [CHANS-1:0] valid_lanes;
            logic [CHANS-1:0] clear_lanes;
            fifo_word_t input_data;
            int channel;
            pre_full = vif.full;
            can_write = !pre_full;
            push = vif.winc && !vif.block_winc && !vif.clear_wr && can_write;
            valid_lanes = vif.write & {CHANS{can_write && !vif.clear_wr}};
            clear_lanes = vif.clear_chan_wr;
            input_data = vif.din;
            #1ps;
            if (!vif.rst_wr_an) begin
                reset_model(1'b1);
                return;
            end
            if (vif.clear_wr) begin
                reset_model(1'b0);
            end else begin
                for (channel = 0; channel < CHANS; channel++) begin
                    if (clear_lanes[channel]) begin
                        int address;
                        lane_clear_seen++;
                        for (address = 0; address < LENGTH; address++)
                            model_mem[address][channel] = MEM_RST_VAL;
                        update_queued_lane(channel, MEM_RST_VAL);
                    end else if (valid_lanes[channel]) begin
                        model_mem[model_wptr[PTR_W-1:0]][channel] =
                            input_data[channel*DATA_W +: DATA_W];
                    end
                end
                if (push) begin
                    expected_q.push_back(memory_word(model_wptr[PTR_W-1:0]));
                    if (model_wptr[PTR_W-1:0] == PTR_W'(LENGTH-1)) wraps_seen++;
                    model_wptr = increment_pointer(model_wptr);
                    writes_accepted++;
                end
            end
            if (vif.wr_ptr_bin !== model_wptr)
                `uvm_error("POINTER", $sformatf(
                    "async write pointer actual=%0d expected=%0d",
                    vif.wr_ptr_bin, model_wptr))
            if (vif.overflow !== (vif.winc && !vif.block_winc && pre_full))
                `uvm_error("OVERFLOW", "async overflow pulse mismatch")
            if (vif.overflow) overflow_seen++;
            if (vif.underflow) underflow_dest_seen++;
            if (vif.block_winc) blocked_seen++;
        endtask

        task process_async_read_edge();
            bit pre_empty;
            bit pop;
            logic [CHANS-1:0] clear_lanes;
            fifo_word_t expected_data;
            int channel;
            pre_empty = vif.empty;
            pop = vif.rinc && !vif.block_rinc && !vif.clear_rd && !pre_empty;
            clear_lanes = vif.clear_chan_rd;
            expected_data = model_dout;
            if (pop)
                expected_data = memory_word(model_rptr[PTR_W-1:0]);
            for (channel = 0; channel < CHANS; channel++)
                if (clear_lanes[channel])
                    expected_data[channel*DATA_W +: DATA_W] = MEM_RST_VAL;
            #1ps;
            if (!vif.rst_rd_an) begin
                expected_q.delete();
                model_rptr = PTR_DEF;
                model_dout = {CHANS{MEM_RST_VAL}};
                return;
            end
            if (vif.clear_rd) begin
                expected_q.delete();
                model_rptr = PTR_DEF;
            end else if (pop) begin
                if (expected_q.size() == 0)
                    `uvm_error("SCOREBOARD", "async accepted read with empty model queue")
                else
                    void'(expected_q.pop_front());
                if (model_rptr[PTR_W-1:0] == PTR_W'(LENGTH-1)) wraps_seen++;
                model_rptr = increment_pointer(model_rptr);
                reads_accepted++;
            end
            if (pop || (clear_lanes != '0)) begin
                model_dout = expected_data;
                if (vif.dout !== model_dout)
                    `uvm_error("DATA", $sformatf(
                        "async dout actual=0x%0h expected=0x%0h at %0t",
                        vif.dout, model_dout, $time))
            end
            if (vif.rd_ptr_bin !== model_rptr)
                `uvm_error("POINTER", $sformatf(
                    "async read pointer actual=%0d expected=%0d",
                    vif.rd_ptr_bin, model_rptr))
            if (vif.rinc && !vif.block_rinc && !vif.clear_rd && pre_empty)
                underflow_source_seen++;
            if (vif.block_rinc) blocked_seen++;
        endtask

        task run_phase(uvm_phase phase);
            if (ASYNCHRONOUS) begin
                fork
                    forever begin
                        @(posedge vif.clk_wr);
                        process_async_write_edge();
                    end
                    forever begin
                        @(posedge vif.clk_rd);
                        process_async_read_edge();
                    end
                join
            end else begin
                forever begin
                    @(posedge vif.clk_wr);
                    process_sync_edge();
                end
            end
        endtask

        function void check_phase(uvm_phase phase);
            super.check_phase(phase);
            if (expected_q.size() != 0)
                `uvm_error("SCOREBOARD", $sformatf(
                    "%0d expected entries remain at end of test",
                    expected_q.size()))
        endfunction

        function void report_phase(uvm_phase phase);
            `uvm_info("COVERAGE", $sformatf(
                "accepted writes=%0d reads=%0d wraps=%0d overflow=%0d underflow-source=%0d underflow-destination=%0d blocked=%0d lane-clears=%0d",
                writes_accepted, reads_accepted, wraps_seen, overflow_seen,
                underflow_source_seen, underflow_dest_seen, blocked_seen,
                lane_clear_seen), UVM_LOW)
        endfunction
    endclass

    class fifo_env extends uvm_env;
        `uvm_component_utils(fifo_env)
        fifo_write_agent write_agent;
        fifo_read_agent read_agent;
        fifo_scoreboard scoreboard;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            write_agent = fifo_write_agent::type_id::create("write_agent", this);
            read_agent = fifo_read_agent::type_id::create("read_agent", this);
            scoreboard = fifo_scoreboard::type_id::create("scoreboard", this);
        endfunction
    endclass

    class fifo_base_test extends uvm_test;
        `uvm_component_utils(fifo_base_test)
        virtual channelized_fifo_if vif;
        fifo_env env;

        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db#(virtual channelized_fifo_if)::get(
                    this, "", "vif", vif))
                `uvm_fatal("NOVIF", "test did not receive vif")
            env = fifo_env::type_id::create("env", this);
        endfunction

        function fifo_word_t pattern(int seed);
            fifo_word_t result;
            int channel;
            result = '0;
            for (channel = 0; channel < CHANS; channel++)
                result[channel*DATA_W +: DATA_W] = DATA_W'(seed + channel*37);
            return result;
        endfunction

        task apply_reset();
            vif.rst_wr_an = 1'b0;
            vif.rst_rd_an = 1'b0;
            fork
                repeat (4) @(posedge vif.clk_wr);
                repeat (4) @(posedge vif.clk_rd);
            join
            fork
                begin @(negedge vif.clk_wr); vif.rst_wr_an = 1'b1; end
                begin @(negedge vif.clk_rd); vif.rst_rd_an = 1'b1; end
            join
            repeat (3) @(posedge vif.clk_wr);
            #2ps;
            if (!vif.empty || vif.full || (vif.how_full_wr != '0) ||
                (vif.how_full_rd != '0) || (vif.wr_ptr_bin != PTR_DEF) ||
                (vif.rd_ptr_bin != PTR_DEF) ||
                (vif.dout !== {CHANS{MEM_RST_VAL}}))
                `uvm_error("RESET", "FIFO reset outputs do not match defaults")
        endtask

        task send_write(bit do_winc, logic [CHANS-1:0] mask,
                        fifo_word_t data, bit blocked = 1'b0,
                        bit pointer_clear = 1'b0,
                        logic [CHANS-1:0] lane_clear = '0);
            fifo_write_sequence seq;
            seq = fifo_write_sequence::type_id::create("write_sequence");
            seq.command.winc = do_winc;
            seq.command.write_mask = mask;
            seq.command.data = data;
            seq.command.block_winc = blocked;
            seq.command.clear_wr = pointer_clear;
            seq.command.clear_chan = lane_clear;
            seq.start(env.write_agent.sequencer);
        endtask

        task send_read(bit do_rinc, bit blocked = 1'b0,
                       bit pointer_clear = 1'b0,
                       logic [CHANS-1:0] lane_clear = '0);
            fifo_read_sequence seq;
            seq = fifo_read_sequence::type_id::create("read_sequence");
            seq.command.rinc = do_rinc;
            seq.command.block_rinc = blocked;
            seq.command.clear_rd = pointer_clear;
            seq.command.clear_chan = lane_clear;
            seq.start(env.read_agent.sequencer);
        endtask

        task write_cycle(bit do_winc, logic [CHANS-1:0] mask,
                         fifo_word_t data, bit blocked = 1'b0,
                         bit pointer_clear = 1'b0,
                         logic [CHANS-1:0] lane_clear = '0);
            send_write(do_winc, mask, data, blocked, pointer_clear, lane_clear);
            @(posedge vif.clk_wr);
            #2ps;
        endtask

        task read_cycle(bit do_rinc, bit blocked = 1'b0,
                        bit pointer_clear = 1'b0,
                        logic [CHANS-1:0] lane_clear = '0);
            send_read(do_rinc, blocked, pointer_clear, lane_clear);
            @(posedge vif.clk_rd);
            #2ps;
        endtask

        task simultaneous_cycle(bit do_winc, logic [CHANS-1:0] mask,
                                fifo_word_t data, bit do_rinc);
            fork
                send_write(do_winc, mask, data);
                send_read(do_rinc);
            join
            @(posedge vif.clk_wr);
            #2ps;
        endtask

        task coordinated_clear();
            fork
                repeat (4)
                    write_cycle(1'b0, '0, '0, 1'b0, 1'b1);
                repeat (4)
                    read_cycle(1'b0, 1'b0, 1'b1);
            join
            fork
                repeat (3) @(posedge vif.clk_wr);
                repeat (3) @(posedge vif.clk_rd);
            join
            #2ps;
        endtask

        task wait_not_empty();
            int timeout;
            timeout = 0;
            while (vif.empty && timeout < 40) begin
                @(posedge vif.clk_rd);
                #2ps;
                timeout++;
            end
            if (vif.empty)
                `uvm_fatal("TIMEOUT", "read domain remained empty")
        endtask

        task wait_empty();
            int timeout;
            timeout = 0;
            while (!vif.empty && timeout < 40) begin
                @(posedge vif.clk_rd);
                #2ps;
                timeout++;
            end
            if (!vif.empty)
                `uvm_fatal("TIMEOUT", "read domain did not become empty")
        endtask

        task wait_write_empty_view();
            int timeout;
            timeout = 0;
            while ((vif.how_full_wr != '0) && timeout < 40) begin
                @(posedge vif.clk_wr);
                #2ps;
                timeout++;
            end
            if (vif.how_full_wr != '0)
                `uvm_fatal("TIMEOUT",
                    "write domain did not observe the completed drain")
        endtask

        task check_common_coverage();
            if (env.scoreboard.writes_accepted < LENGTH)
                `uvm_error("COVERAGE", "test did not accept at least one FIFO depth of writes")
            if (env.scoreboard.reads_accepted < LENGTH)
                `uvm_error("COVERAGE", "test did not accept at least one FIFO depth of reads")
            if (env.scoreboard.overflow_seen == 0)
                `uvm_error("COVERAGE", "overflow scenario was not observed")
            if (env.scoreboard.underflow_source_seen == 0)
                `uvm_error("COVERAGE", "underflow request was not observed")
            if (env.scoreboard.wraps_seen < 2)
                `uvm_error("COVERAGE", "both pointer wrap paths were not observed")
        endtask
    endclass

    class channelized_fifo_sync_test extends fifo_base_test;
        `uvm_component_utils(channelized_fifo_sync_test)
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            fifo_word_t value;
            logic [CHANS-1:0] first_lane;
            logic [CHANS-1:0] other_lanes;
            int index;
            phase.raise_objection(this);
            apply_reset();

            first_lane = '0;
            first_lane[0] = 1'b1;
            other_lanes = {CHANS{1'b1}} & ~first_lane;

            // Build one entry over multiple write clocks before committing it.
            write_cycle(1'b0, first_lane, pattern('h10));
            write_cycle(1'b1, other_lanes, pattern('h40));
            read_cycle(1'b1);

            // A pointer-only enqueue is legal and exposes retained slot data.
            write_cycle(1'b1, '0, '0);
            read_cycle(1'b1);

            // Fill every occupancy, reject one write, and exercise blocking.
            for (index = 0; index < LENGTH; index++)
                write_cycle(1'b1, {CHANS{1'b1}}, pattern('h60 + index));
            if (!vif.full) `uvm_error("BOUNDARY", "FIFO did not assert full")
            write_cycle(1'b1, {CHANS{1'b1}}, pattern('hee));
            if (!vif.overflow) `uvm_error("BOUNDARY", "overflow was not asserted")
            write_cycle(1'b1, {CHANS{1'b1}}, pattern('hef), 1'b1);
            for (index = 0; index < LENGTH; index++)
                read_cycle(1'b1);
            if (!vif.empty) `uvm_error("BOUNDARY", "FIFO did not assert empty")
            read_cycle(1'b1);
            if (!vif.underflow) `uvm_error("BOUNDARY", "underflow was not asserted")
            read_cycle(1'b1, 1'b1);

            // Fill entries, clear one lane throughout memory, then drain.
            for (index = 0; index < LENGTH; index++)
                write_cycle(1'b1, {CHANS{1'b1}}, pattern('h90 + index));
            write_cycle(1'b0, '0, '0, 1'b0, 1'b0, first_lane);
            read_cycle(1'b0, 1'b0, 1'b0, first_lane);
            for (index = 0; index < LENGTH; index++)
                read_cycle(1'b1);

            // Repeated fill/drain gives deterministic multi-wrap stress.
            for (int pass = 0; pass < 3; pass++) begin
                for (index = 0; index < LENGTH; index++)
                    write_cycle(1'b1, {CHANS{1'b1}},
                                pattern(pass*LENGTH + index));
                for (index = 0; index < LENGTH; index++)
                    read_cycle(1'b1);
            end

            // Pointer clear/flush while entries are present.
            write_cycle(1'b1, {CHANS{1'b1}}, pattern('hc1));
            coordinated_clear();
            if (!vif.empty || vif.wr_ptr_bin != PTR_DEF ||
                vif.rd_ptr_bin != PTR_DEF)
                `uvm_error("CLEAR", "coordinated clear did not restore empty defaults")

            check_common_coverage();
            phase.drop_objection(this);
        endtask
    endclass

    class channelized_fifo_low_latency_test extends fifo_base_test;
        `uvm_component_utils(channelized_fifo_low_latency_test)
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            logic [CHANS-1:0] all_lanes;
            logic [CHANS-1:0] lane_zero;
            int index;
            phase.raise_objection(this);
            apply_reset();
            all_lanes = {CHANS{1'b1}};
            lane_zero = '0;
            lane_zero[0] = 1'b1;

            write_cycle(1'b1, all_lanes, pattern('h11));
            if (vif.dout !== pattern('h11))
                `uvm_error("LOWLAT", "first-word fall-through failed")
            write_cycle(1'b1, all_lanes, pattern('h22));
            read_cycle(1'b1);
            if (vif.dout !== pattern('h22))
                `uvm_error("LOWLAT", "next-head prefetch failed")
            simultaneous_cycle(1'b1, all_lanes, pattern('h33), 1'b1);
            if (vif.dout !== pattern('h33))
                `uvm_error("LOWLAT", "occupancy-one replacement failed")
            read_cycle(1'b1);

            // Clear priority over write-through at empty.
            write_cycle(1'b1, all_lanes, pattern('h44), 1'b0, 1'b0, lane_zero);
            if (vif.dout[DATA_W-1:0] !== MEM_RST_VAL)
                `uvm_error("LOWLAT", "lane clear lost priority over write-through")
            read_cycle(1'b1);

            for (index = 0; index < LENGTH; index++)
                write_cycle(1'b1, all_lanes, pattern('h70 + index));
            simultaneous_cycle(1'b1, all_lanes, pattern('ha0), 1'b1);
            if (!vif.full)
                `uvm_error("LOWLAT", "full simultaneous replacement changed occupancy")
            write_cycle(1'b1, all_lanes, pattern('hfe));
            for (index = 0; index < LENGTH; index++)
                read_cycle(1'b1);
            read_cycle(1'b1);

            if (env.scoreboard.overflow_seen == 0 ||
                env.scoreboard.underflow_source_seen == 0)
                `uvm_error("COVERAGE", "low-latency boundary events missing")
            phase.drop_objection(this);
        endtask
    endclass

    class channelized_fifo_async_test extends fifo_base_test;
        `uvm_component_utils(channelized_fifo_async_test)
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        task run_phase(uvm_phase phase);
            logic [CHANS-1:0] all_lanes;
            int index;
            int pass;
            int timeout;
            phase.raise_objection(this);
            apply_reset();
            all_lanes = {CHANS{1'b1}};

            // Multiple complete traversals exercise wrap and Gray skip edges.
            for (pass = 0; pass < 3; pass++) begin
                for (index = 0; index < LENGTH; index++)
                    write_cycle(1'b1, all_lanes,
                                pattern('h20 + pass*LENGTH + index));
                if (!vif.full)
                    `uvm_error("ASYNC", "write domain did not reach full")
                write_cycle(1'b1, all_lanes, pattern('hff));
                wait_not_empty();
                for (index = 0; index < LENGTH; index++)
                    read_cycle(1'b1);
                wait_empty();
                // Empty is a read-domain fact.  Before beginning another
                // full-depth burst, allow its pointer to cross back so the
                // write domain no longer conservatively reports full.
                wait_write_empty_view();
            end

            // Deterministic producer/consumer overlap exercises pointer CDC
            // while both local domains are actively changing.
            fork
                begin : streaming_producer
                    for (int stream_write = 0;
                         stream_write < (2*LENGTH); stream_write++) begin
                        while (vif.full) begin
                            @(posedge vif.clk_wr);
                            #2ps;
                        end
                        write_cycle(1'b1, all_lanes,
                                    pattern('h80 + stream_write));
                    end
                end
                begin : streaming_consumer
                    for (int stream_read = 0;
                         stream_read < (2*LENGTH); stream_read++) begin
                        wait_not_empty();
                        read_cycle(1'b1);
                    end
                end
            join
            wait_empty();
            wait_write_empty_view();

            read_cycle(1'b1);
            timeout = 0;
            while (!vif.underflow && timeout < 40) begin
                @(posedge vif.clk_wr);
                #2ps;
                timeout++;
            end
            if (!vif.underflow)
                `uvm_error("CDC", "underflow event did not reach write clock domain")

            // Verify coordinated CDC flush after synchronized state is live.
            write_cycle(1'b1, all_lanes, pattern('hc0));
            write_cycle(1'b1, all_lanes, pattern('hc1));
            wait_not_empty();
            coordinated_clear();
            wait_empty();

            check_common_coverage();
            if (env.scoreboard.underflow_dest_seen == 0)
                `uvm_error("COVERAGE", "underflow destination pulse was not observed")
            phase.drop_objection(this);
        endtask
    endclass

endpackage

`default_nettype wire
