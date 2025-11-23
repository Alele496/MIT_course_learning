import Ehr::*;
import Vector::*;

//////////////////
// Fifo interface 

interface Fifo#(numeric type n, type t);
    method Bool notFull;
    method Action enq(t x);
    method Bool notEmpty;
    method Action deq;
    method t first;
    method Action clear;
endinterface

/////////////////
// Conflict FIFO

module mkMyConflictFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
    Reg#(Bit#(TLog#(n)))    enqP     <- mkReg(0);
    Reg#(Bit#(TLog#(n)))    deqP     <- mkReg(0);
    Reg#(Bool)              empty    <- mkReg(True);
    Reg#(Bool)              full     <- mkReg(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    // TODO: Implement all the methods for this module

    method Bool notFull() = !full;
    method Bool notEmpty() = !empty;

    method Action enq(t x) if(!full);
        data[enqP] <= x;
        // let next_enqP = (enqP + 1) & max_index;  // mod max_index: Atfer reaching the maximum range, taje the modules as 0 and continue the cycle
        let next_enqP = enqP == max_index ? 0 : enqP + 1;
        enqP <= next_enqP;

        empty <= False;

        if (next_enqP == deqP) begin
            full <= True;
        end 
            else full <= False;
    
    endmethod

    method Action deq() if(!empty);
        // let next_deqP = (deqP + 1) & max_index;
        let next_deqP = deqP == max_index ? 0 : deqP + 1;

        deqP <= next_deqP;

        full <= False;

        if (next_deqP == enqP) begin
            empty <= True; 
        end
            else empty <= False;

    endmethod

    method t first() if(!empty);
        return data[deqP];
    endmethod

    method Action clear();
        enqP <= 0;
        deqP <= 0;
        empty <= True;
        full <= False;
    endmethod

endmodule

/////////////////
// Pipeline FIFO

// Intended schedule:
//      {notEmpty, first, deq} < {notFull, enq} < clear
module mkMyPipelineFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
    Ehr#(3, Bit#(TLog#(n))) enqP      <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n))) deqP      <- mkEhr(0);
    Ehr#(3, Bool)           empty    <- mkEhr(True);
    Ehr#(3, Bool)           full     <- mkEhr(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    // TODO: Implement all the methods for this module
    // {notEmpty, first, deq} < {notFull, enq} < clear : deq,first,empty is [0]. enq,full is [1]. clear is [2]
    method Bool notFull() = !full[1];
    method Bool notEmpty() = !empty[0];

    method Action enq(t x) if(!full[1]);
        data[enqP[1]] <= x;
        empty[1] <= False;
        // let next_enqP = (enqP[1] + 1) & max_index;     // Bitwise operations can only be used on powers of 2
        let next_enqP = enqP[1] == max_index ? 0 : enqP[1] + 1;
        if (next_enqP == deqP[1]) begin
            full[1] <= True;
        end 
            else full[1] <= False;
        enqP[1] <= next_enqP; 
    endmethod

    method Action deq() if(!empty[0]);
        full[0] <= False;
        // let next_deqP = (deqP[0] + 1) & max_index;
        let next_deqP = deqP[0] == max_index ? 0 : deqP[0] + 1;
        if (next_deqP == enqP[0]) begin
            empty[0] <= True;
        end
            else empty[0] <= False;
        deqP[0] <= next_deqP;
    endmethod

    method t first if(!empty[0]);
        return data[deqP[0]];
    endmethod

    method Action clear();
        enqP[2] <= 0;
        deqP[2] <= 0;
        empty[2] <= True;
        full[2] <= False;
    endmethod

endmodule

/////////////////////////////
// Bypass FIFO without clear

// Intended schedule:
//      {notFull, enq} < {notEmpty, first, deq} < clear
module mkMyBypassFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
Vector#(n, Reg#(t))     data     <- replicateM(mkRegU());
    Ehr#(3, Bit#(TLog#(n))) enqP      <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n))) deqP      <- mkEhr(0);
    Ehr#(3, Bool)           empty    <- mkEhr(True);
    Ehr#(3, Bool)           full     <- mkEhr(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    // TODO: Implement all the methods for this module
    // {notFull, enq} < {notEmpty, first, deq} < clear : enq,full is [0]. deq,first,empty is [1]. clear is [2]
    method Bool notFull() = !full[0];
    method Bool notEmpty() = !empty[1];

    method Action enq(t x) if(!full[0]);
        data[enqP[0]] <= x;
        empty[0] <= False;
        // let next_enqP = (enqP[0] + 1) & max_index;     // Bitwise operations can only be used on powers of 2
        let next_enqP = enqP[0] == max_index ? 0 : enqP[0] + 1;
        if (next_enqP == deqP[0]) begin
            full[0] <= True;
        end 
            else full[0] <= False;
        enqP[0] <= next_enqP; 
    endmethod

    method Action deq() if(!empty[1]);
        full[1] <= False;
        // let next_deqP = (deqP[1] + 1) & max_index;
        let next_deqP = deqP[1] == max_index ? 0 : deqP[1] + 1;
        if (next_deqP == enqP[1]) begin
            empty[1] <= True;
        end
            else empty[1] <= False;
        deqP[1] <= next_deqP;
    endmethod

    method t first if(!empty[1]);
        return data[deqP[1]];
    endmethod

    method Action clear();
        enqP[2] <= 0;
        deqP[2] <= 0;
        empty[2] <= True;
        full[2] <= False;
    endmethod
endmodule

//////////////////////
// Conflict free fifo

// Intended schedule:
//      {notFull, enq} CF {notEmpty, first, deq}
//      {notFull, enq, notEmpty, first, deq} < clear
module mkMyCFFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    // n is size of fifo
    // t is data type of fifo
    Vector#(n, Reg#(t))        data     <- replicateM(mkRegU());
    Ehr#(3, Bit#(TLog#(n)))    enqP     <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n)))    deqP     <- mkEhr(0);
    Ehr#(3, Bool)              empty    <- mkEhr(True);
    Ehr#(3, Bool)              full     <- mkEhr(False);

    // Initial No Requests
    Ehr#(3, Maybe#(t)) enqReq <- mkEhr(tagged Invalid);
    Ehr#(3, Bool)      deqReq <- mkEhr(False);

    // useful value
    Bit#(TLog#(n))          max_index = fromInteger(valueOf(n)-1);

    // Helper function for pointer advancement
    function Bit#(TLog#(n)) nextPtr(Bit#(TLog#(n)) ptr);
        return (ptr == max_index) ? 0 : (ptr + 1);
    endfunction

    (* no_implicit_conditions *)
    (* fire_when_enabled *)
    rule canonicalize;

        // Next point
        let next_enqP = nextPtr(enqP[1]);
        let next_deqP = nextPtr(deqP[1]);

        Bool can_do_enq = isValid(enqReq[1]) && !full[1];
        Bool can_do_deq = deqReq[1] && !empty[1];

        // Update enq's data and pointer
        if (can_do_enq) begin
            data[enqP[1]] <= fromMaybe(?, enqReq[1]);

            enqP[1] <= next_enqP;
        end

        // Update enq's data and pointer
        if (can_do_deq) begin
            deqP[1] <= next_deqP;
        end

        Bool empty_update;
        Bool full_update;

        // Enumeration condition
        // Both
        if (can_do_enq && can_do_deq) begin
            empty_update = False;
            full_update = full[1];
            // Execute deq
        end else if (!can_do_enq && can_do_deq) begin
            full_update = False;

            if (next_deqP == enqP[1]) begin
                empty_update = True;
            end else empty_update = False;
            // Execute enq
        end else if (can_do_enq && !can_do_deq) begin
            empty_update = False;

            if (next_enqP == deqP[1]) begin
                full_update = True;
            end else full_update = False;

        end else begin
            empty_update = empty[1];
            full_update = full[1];
        end

        // Update
        empty[1] <= empty_update;
        full[1] <= full_update;

        // Clear state
        enqReq[1] <= tagged Invalid;
        deqReq[1] <= False;

    endrule

    // TODO: Implement all the methods for this module
    method Bool notFull() = !full[0];
    method Bool notEmpty() = !empty[0];

    method Action enq(t x) if(!full[0]);
        enqReq[0] <= tagged Valid x;
    endmethod

    method Action deq if(!empty[0]);
        deqReq[0] <= True;
    endmethod

    method t first if(!empty[0]);
        return data[deqP[0]];
    endmethod

    method Action clear();
        enqReq[2] <= tagged Invalid;
        deqReq[2] <= False;
        enqP[2] <= 0;
        deqP[2] <= 0;
        empty[2] <= True;
        full[2] <= False;
    endmethod

endmodule
