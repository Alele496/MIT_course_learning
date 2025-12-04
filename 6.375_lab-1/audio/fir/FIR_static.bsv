// The Fir Filter Module Definition
module mkFIRFilter (AudioProcessor);

    FIFO#(Sample) infifo <- mkFIFO();
    FIFO#(Sample) outfifo <- mkFIFO();

    Vector#(8, Reg#(Sample)) r <- replicateM(mkReg(0));

    /* 
    // Initial Reg
    Reg#(Sample) r0 <- mkReg(0);
    Reg#(Sample) r1 <- mkReg(0);
    Reg#(Sample) r2 <- mkReg(0);
    Reg#(Sample) r3 <- mkReg(0);
    Reg#(Sample) r4 <- mkReg(0);
    Reg#(Sample) r5 <- mkReg(0);
    Reg#(Sample) r6 <- mkReg(0);
    Reg#(Sample) r7 <- mkReg(0);
    */

    Vector#(9, Multiplier) multipliers <- replicateM(mkMultiplier());

    // processor
    rule process_input;
        Sample sample = infifo.first();
        infifo.deq();

        r[0] <= sample;
        for (Integer i = 0; i < 7; i = i + 1) begin
            r[i + 1] <= r[i];
        end

        /* 
        r1 <= r0;
        r2 <= r1;
        r3 <= r2;
        r4 <= r3;
        r5 <= r4;
        r6 <= r5;
        r7 <= r6;
        */

        multipliers[0].putOperands(c[0], sample);
        for (Integer i = 0; i < 8; i = i + 1) begin
            multipliers[i + 1].putOperands(c[i + 1], r[i]);
        end
        
        // unstatic
        /* 
        FixedPoint#(16, 16) accumulate = 
              c[0] * fromInt(sample)
            + c[1] * fromInt(r0)
            + c[2] * fromInt(r1)
            + c[3] * fromInt(r2)
            + c[4] * fromInt(r3)
            + c[5] * fromInt(r4)
            + c[6] * fromInt(r5)
            + c[7] * fromInt(r6)
            + c[8] * fromInt(r7);
        */

    endrule

    // Accumulate result
    rule accumulate_result;
        FixedPoint#(16, 16) result = 0;
        for (Integer i = 0; i < 9; i = i + 1) begin
            // Extract and get result
            let temp <- multipliers[i].getResult();
            result = result + temp;
        end
        
        outfifo.enq (fxptGetInt(result));
    endrule

    method Action putSampleInput(Sample in);
        infifo.enq(in);
    endmethod

    method ActionValue#(Sample) getSampleOutput();
        outfifo.deq();
        return outfifo.first();
    endmethod

endmodule

