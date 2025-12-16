import FIFO::*;
import FixedPoint::*;
import Vector::*;

import AudioProcessorTypes::*;
import FilterCoefficients::*;
import Multiplier::*;


module mkFIRFilter (Vector#(taps, FixedPoint#(16,16)) coeffs, AudioProcessor ifc);

    // Integer numTaps = valueof(taps);

    FIFO#(Sample) infifo <- mkFIFO();
    FIFO#(Sample) outfifo <- mkFIFO();

    Vector#(8, Reg#(Sample)) r <- replicateM(mkReg(0));

    Vector#(taps, Multiplier) multipliers <- replicateM(mkMultiplier());

    // processor
    rule process_input;
        Sample sample = infifo.first();
        infifo.deq();

        r[0] <= sample;
        for (Integer i = 0; i < 7; i = i + 1) begin
            r[i + 1] <= r[i];
        end

        multipliers[0].putOperands(coeffs[0], sample);

        for (Integer i = 0; i < 8; i = i + 1) begin
            multipliers[i + 1].putOperands(coeffs[i + 1], r[i]);
        end

     endrule

    // Accumulate result
    rule accumulate_result;
        FixedPoint#(16, 16) result = 0;
        for (Integer i = 0; i < valueof(taps); i = i + 1) begin
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


/* 

*/

