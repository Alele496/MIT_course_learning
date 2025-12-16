import Complex::*;
import FixedPoint::*;
import Vector::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;
import ComplexMP::*;

import Cordic::*;

// ToMP Interface
typedef Server#(
    Vector#(nbins, ComplexMP#(isize, fsize, psize)),
    Vector#(nbins, Complex#(FixedPoint#(isize, fsize)))
) FromMP#(numeric type nbins, numeric type isize, numeric type fsize, numeric type psize);


module mkFromMP (FromMP#(nbins, isize, fsize, psize))
    provisos(
        Add#(1, __i, isize),  // i >= 1
        Add#(1, __f, fsize),  // f >= 1
        Add#(1, __p, psize),  // p >= 1
        Add#(TLog#(TAdd#(nbins, 1)), __b, 32)
    );

    FIFO#(Vector#(nbins, ComplexMP#(isize, fsize, psize))) inputFIFO <- mkFIFO();
    FIFO#(Vector#(nbins, Complex#(FixedPoint#(isize, fsize)))) outputFIFO <- mkFIFO();

    FromMagnitudePhase#(isize, fsize, psize) cordic <- mkCordicFromMagnitudePhase();

    // State machine
    Reg#(Maybe#(Vector#(nbins, ComplexMP#(isize, fsize, psize)))) currentInput <- mkReg(tagged Invalid);
    Reg#(Vector#(nbins, Complex#(FixedPoint#(isize, fsize)))) currentOutput <- mkRegU();
    Reg#(Bit#(TAdd#(nbins, 1))) state <- mkReg(0);
    Reg#(Bool) processing <- mkReg(False);

    // Input valid, processing has not started
    rule getNewInput(!processing && !isValid(currentInput));
        let input_vec = inputFIFO.first();
        inputFIFO.deq();

        // Handshake signal
        currentInput <= tagged Valid input_vec;
        // Reset
        currentOutput <= replicate(cmplx(0, 0));
        state <= 0;
    endrule

    rule startProcessing(!processing && isValid(currentInput) && state == 0);
        let input_vec = fromMaybe(?, currentInput);

        cordic.request.put(input_vec[0]);
        state <= 1;
        processing <= True;
    endrule

    rule processCordic(processing);
        let result <- cordic.response.get();

        // update state and output
        let resu1tIdx = state - 1;
        let updateOutput = currentOutput;
        updateOutput[resu1tIdx] = result;
        currentOutput <= updateOutput;

        if (resu1tIdx < fromInteger(valueOf(nbins))) begin
            let input_vec = fromMaybe(?, currentInput);
            cordic.request.put(input_vec[0]);
            state <= state + 1;
        end else begin
            outputFIFO.enq(updateOutput);
            currentInput <= tagged Invalid;
            processing <= False;
        end
        
    endrule

    interface Put request = toPut(inputFIFO);
    interface Get response = toGet(outputFIFO);

endmodule