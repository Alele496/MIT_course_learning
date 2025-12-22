// FourCycle.bsv
//
// This is a four cycle implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import DelayedMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;

typedef enum {
    Fetch, 
    Decode,
    Execute,
    WriteBack
} Stage deriving(Bits, Eq, FShow);

(* synthesize *)
module mkProc(Proc);
    Reg#(Addr) pc <- mkRegU;
    RFile      rf <- mkRFile;
    DelayedMemory  mem <- mkDelayedMemory;
    CsrFile  csrf <- mkCsrFile;

    Reg#(Stage) stage <- mkReg(Fetch);

    Bool memReady = mem.init.done();
    Reg#(DecodedInst) dInst <- mkRegU();
    Reg#(ExecInst) eInst <- mkRegU();

    rule test (!memReady);
	    let e = tagged InitDone;
	    mem.init.request.put(e);
    endrule

    rule doFetch(csrf.started && (stage == Fetch) && memReady);
        mem.req(MemReq{op: Ld, addr: pc, data: ?});
        stage <= Decode;
    endrule

    rule doDecode(csrf.started && (stage == Decode) && memReady);
        // Decode
        Data inst <- mem.resp();
        dInst <= decode(inst);
        stage <= Execute;

        // Trace-stdout
        $display("pc: %h inst: (%h) expanded:", pc, inst, showInst(inst));
        $fflush(stdout);
    endrule

    rule doExecute(csrf.started && (stage == Execute) && memReady);

        // read general purpose register values 
        Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));

        // read CSR values (for CSRR inst)
        Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

        // execute
        ExecInst eInst_temp = exec(dInst, rVal1, rVal2, pc, ?, csrVal);  
		// The fifth argument above is the predicted pc, to detect if it was mispredicted. 
		// Since there is no branch prediction, this field is sent with a random value

        // memory
        if(eInst_temp.iType == Ld) begin
            mem.req(MemReq{op: Ld, addr: eInst_temp.addr, data: ?});
        end else if(eInst_temp.iType == St) begin
            mem.req(MemReq{op: St, addr: eInst_temp.addr, data: eInst_temp.data});
        end

        eInst <= eInst_temp;
        stage <= WriteBack;
    endrule

    rule doWriteBack(csrf.started && (stage == WriteBack) && memReady);
        // commit


        // check unsupported instruction at commit time. Exiting
        if(eInst.iType == Unsupported) begin
            $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", pc);
            $finish;
        end

        ExecInst eInst_temp = eInst;

        if (eInst_temp.iType == Ld) begin
            eInst_temp.data <- mem.resp();
        end

        // write back to reg file
        if(isValid(eInst.dst)) begin
            rf.wr(fromMaybe(?, eInst.dst), eInst.data);
        end

        // update the pc depending on whether the branch is taken or not
        pc <= eInst.brTaken ? eInst.addr : pc + 4;

        // CSR write for sending data to host & stats
        csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);

        // Set stage
        stage <= Fetch;
    endrule

    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
        csrf.start(0); // only 1 core, id = 0
	$display("Start at pc 200\n");
	$fflush(stdout);
        pc <= startpc;
    endmethod

    interface iMemInit = mem.init;
    interface dMemInit = mem.init;
endmodule

