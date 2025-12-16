
import ClientServer::*;
import FIFO::*;
import GetPut::*;

import FixedPoint::*;
import Vector::*;

import ComplexMP::*;


typedef Server#(
    Vector#(nbins, ComplexMP#(isize, fsize, psize)),
    Vector#(nbins, ComplexMP#(isize, fsize, psize))
) PitchAdjust#(numeric type nbins, numeric type isize, numeric type fsize, numeric type psize);


interface SettablePitchAdjust#(
        numeric type nbins, numeric type isize,
        numeric type fsize, numeric type psize
    );

    interface PitchAdjust#(nbins, isize, fsize, psize) adjust; 
    interface Put#(FixedPoint#(isize, fsize)) setFactor; 
endinterface

// s - the amount each window is shifted from the previous window.
//
// factor - the amount to adjust the pitch.
//  1.0 makes no change. 2.0 goes up an octave, 0.5 goes down an octave, etc...
module mkPitchAdjust(Integer s, SettablePitchAdjust#(nbins, isize, fsize, psize) ifc)
        provisos(
            Add#(psize, a_, isize), // isize >= psize
            Add#(a__, psize, TAdd#(isize, isize)),

            // 针对pitch.c代码的浮点数，所作约束条件
            // 新增的约束
            Min#(isize, 1, 1),                      // 整数部分至少1位
            Min#(fsize, 1, 1),                      // 小数部分至少1位
            Arith#(FixedPoint#(isize, fsize)),      // FixedPoint支持算术运算
            Bits#(FixedPoint#(isize, fsize), t0),   // FixedPoint支持位操作
            Eq#(FixedPoint#(isize, fsize)),         // FixedPoint支持相等比较
            Literal#(FixedPoint#(isize, fsize)),    // FixedPoint支持字面量
            Ord#(FixedPoint#(isize, fsize)),        // FixedPoint支持排序
    
            // 确保总位数足够
            Add#(isize, fsize, total_bits),
            Min#(total_bits, 2, 2)
        );
    
    // TODO: implement this module 

    // Maybe type ensure valid values are entered
    // Reg#(FixedPoint#(isize, fsize)) factor <- mkReg(0);
    Reg#(Maybe#(FixedPoint#(isize, fsize))) factorReg <- mkReg(tagged Invalid);

    // Input, Output FIFO
    FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) inputFIFO <- mkFIFO();
    FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) outputFIFO <- mkFIFO();

    // Last input phase of each bin
    Vector#(nbins, Reg#(Phase#(psize))) in_phases <- replicateM(mkReg(0));
    // Last output phase of each bin
    Vector#(nbins, Reg#(Phase#(psize))) out_phases <- replicateM(mkReg(0));

    // processor
    rule process_frame if (factorReg matches tagged Valid .factor);

        Vector#(nbins, ComplexMP#(isize, fsize, psize)) in_vec = replicate(cmplxmp(0, 0));
        Vector#(nbins, ComplexMP#(isize, fsize, psize)) out_vec = replicate(cmplxmp(0, 0));

        // Fetch input frame
        in_vec = inputFIFO.first;
        inputFIFO.deq();

        // Read current value of output register
        Vector#(nbins, Phase#(psize)) current_out_phases;
        for (Integer j = 0; j < valueOf(nbins); j = j + 1) begin
            current_out_phases[j] = out_phases[j];
        end

        // process
        for (Integer i = 0; i < valueOf(nbins); i = i + 1) begin

            // Fetch mag and phase
            FixedPoint#(isize, fsize) mag = in_vec[i].magnitude;
            Phase#(psize) phase = in_vec[i].phase;
            Phase#(psize) phase_diff = phase - in_phases[i];

            // update input phase
            in_phases[i] <= phase;
            FixedPoint#(isize, fsize) phase_diff_int = fromInt(phase_diff);

            Int#(isize) bin = fxptGetInt(fromInteger(i) * factor);
            Int#(isize) next_bin = fxptGetInt(fromInteger(i + 1) * factor);

            if (bin != next_bin && bin >= 0 && bin < fromInteger(valueOf(nbins))) begin

                // Cumulative phase
                let shifted = fxptGetInt(fxptMult(phase_diff_int, factor));
                Phase#(psize) shifted_res = truncate(shifted);
                    
                current_out_phases[bin] = current_out_phases[bin] + shifted_res;

                out_vec[bin] = cmplxmp(mag, current_out_phases[bin]);           
            end
        end

        // Write once Avoid cycle Conflicts
        for (Integer j = 0; j < valueOf(nbins); j = j + 1) begin
            out_phases[j] <= current_out_phases[j];
        end

        outputFIFO.enq(out_vec);

    endrule

    /* 
    interface Put request;
        method Action put(Vector#(nbins, ComplexMP#(isize, fsize, psize)) x);
            inputFIFO.enq(x);
        endmethod
    endinterface

    interface Get response = toGet(outputFIFO);
    */
    interface PitchAdjust adjust;
        interface Put request;
            method Action put(Vector#(nbins, ComplexMP#(isize, fsize, psize)) x);
                inputFIFO.enq(x);
            endmethod
        endinterface
        interface Get response = toGet(outputFIFO);
    endinterface

    interface Put setFactor;
        method Action put(FixedPoint#(isize, fsize) x) if(!isValid(factorReg));
            // factor <= x;
            factorReg <= tagged Valid x;
        endmethod
    endinterface

endmodule

