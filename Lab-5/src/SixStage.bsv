// SixStage.bsv
//
// This is a six stage implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import FPGAMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;
import Btb::*;
import Scoreboard::*;

typedef struct {
    Addr pc;
    Addr predPc;
    Bool epoch;
} Fetch2Decode deriving (Bits, Eq, FShow);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Bool epoch;
} Decode2RegFetch deriving (Bits, Eq, FShow);

typedef struct {
    Addr pc;
    Addr predPc;
    DecodedInst dInst;
    Data rVal1;
    Data rVal2;
    Data csrVal;
    Bool epoch;
} RegFetch2Execute deriving (Bits, Eq, FShow);

typedef struct {
    Addr pc;
    Addr predPc;
    ExecInst eInst;
    Bool epoch;
} Execute2Memory deriving (Bits, Eq, FShow);

typedef struct {
    ExecInst eInst;
    Bool epoch;
} Memory2WriteBack deriving (Bits, Eq, FShow);

typedef struct {
    Addr pc;
    Addr nextPc;
} ExeRedirect deriving (Bits, Eq, FShow);

(* synthesize *)
module mkProc(Proc);
    // Reg#(Addr) pc <- mkRegU;
    Ehr#(2, Addr) pcReg <- mkEhr(?);
    RFile      rf <- mkRFile;
    FPGAMemory  iMem <- mkFPGAMemory;
    FPGAMemory  dMem <- mkFPGAMemory;
    CsrFile  csrf <- mkCsrFile;
    Scoreboard#(6) sb <- mkCFScoreboard;


    Btb#(8) btb <- mkBtb();

    // Assembly line
    Fifo#(2, Fetch2Decode) f2dFifo <- mkCFFifo();
    Fifo#(2, Decode2RegFetch) d2rfFifo <- mkCFFifo();
    Fifo#(2, RegFetch2Execute) rf2eFifo <- mkCFFifo();
    Fifo#(2, Execute2Memory) e2mFifo <- mkCFFifo();
    Fifo#(2, Memory2WriteBack) m2wbFifo <- mkCFFifo();

    // Global epoch
    Reg#(Bool) eEpoch <- mkReg(False);
    Ehr#(2, Maybe#(ExeRedirect)) exeRedirect <- mkEhr(Invalid);


    Bool memReady = iMem.init.done() && dMem.init.done();
    rule test (!memReady);
	    let e = tagged InitDone;
	    iMem.init.request.put(e);
	    dMem.init.request.put(e);
    endrule

    rule doInstructFetch(csrf.started);
        // fetch instruct
        iMem.req(MemReq{op: Ld, addr: pcReg[0], data: ?});
        // prediction
        Addr nextPc = btb.predPc(pcReg[0]);

        pcReg[0] <= nextPc;

        Fetch2Decode data = Fetch2Decode {
            pc: pcReg[0],
            predPc: nextPc,
            epoch: eEpoch
        };

        f2dFifo.enq(data);
        $display("[IF] PC=%h, BTB Pred=%h, Epoch=%b", pcReg[0], nextPc, eEpoch);
    endrule

    rule doDecode(csrf.started);
        let f2d = f2dFifo.first;
        f2dFifo.deq;

        let inst <- iMem.resp;
        DecodedInst dInst = decode(inst);
        Decode2RegFetch data = Decode2RegFetch {
            pc: f2d.pc,
            predPc: f2d.predPc,
            dInst: dInst,
            epoch: f2d.epoch
        };

        d2rfFifo.enq(data);
        $display("[ID] PC=%h, Inst=%h, BTB Pred=%h, Epoch=%b", f2d.pc, f2d.predPc, f2d.epoch);
    endrule

    rule doRegFetch(csrf.started);
        let d2rf = d2rfFifo.first;
        let dInst = d2rf.dInst;

        Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
        Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));
        Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

        RegFetch2Execute data = RegFetch2Execute {
            pc: d2rf.pc,
            predPc: d2rf.predPc,
            dInst: d2rf.dInst,
            rVal1: rVal1,
            rVal2: rVal2,
            csrVal: csrVal,
            epoch: d2rf.epoch
        };

        if (!sb.search1(dInst.src1) && !sb.search2(dInst.src2)) begin
            d2rfFifo.deq();
            rf2eFifo.enq(data);
            sb.insert(dInst.dst);
            $display("[RF] PC=%h, Inst=%h, Epoch=%b", d2rf.pc, d2rf.epoch);
        end else begin
            $display("[RF]-> (Stalled) PC=%h, Epoch=%b", d2rf.pc, d2rf.epoch);
        end
    endrule

    rule doExecute(csrf.started);
        let rf2e = rf2eFifo.first;
        rf2eFifo.deq();
        
        if (rf2e.epoch == eEpoch) begin
            ExecInst eInst = exec(rf2e.dInst, rf2e.rVal1, rf2e.rVal2, rf2e.pc, rf2e.predPc, rf2e.csrVal);

            if (eInst.iType == Unsupported) begin
                $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", rf2e.pc);
                $finish;
            end

            if (eInst.mispredict) begin
                // Redirect
                exeRedirect[0] <= Valid(ExeRedirect{
                    pc: rf2e.pc,
                    nextPc: eInst.addr
                });
                $display("[EX]-> (Mispredict) PC=%h, Pred=%h, Epoch=%b, Actual=%h", rf2e.pc, rf2e.predPc, rf2e.epoch, eInst.addr);
            end

            Execute2Memory data = Execute2Memory {
                pc: rf2e.pc,
                predPc: rf2e.predPc,
                eInst: eInst,
                epoch: rf2e.epoch
            };

            e2mFifo.enq(data);
        end else begin
            $display("[EX]-> (Drop) PC=%h", rf2e.pc);
        end

    endrule

    rule doMemory(csrf.started);
        let e2m = e2mFifo.first;
        e2mFifo.deq();

        if (e2m.eInst.iType == Ld) begin
            dMem.req(MemReq{op: Ld, addr: e2m.eInst.addr, data: ?});
        end else if (e2m.eInst.iType == St) begin
            dMem.req(MemReq{op: St, addr: e2m.eInst.addr, data: e2m.eInst.data});
        end

        Memory2WriteBack data = Memory2WriteBack{
            eInst: e2m.eInst,
            epoch: e2m.epoch
        };

        m2wbFifo.enq(data);

    endrule

    rule doWriteBack(csrf.started);
        let m2wb = m2wbFifo.first;
        m2wbFifo.deq();

        if (m2wb.epoch == eEpoch) begin
            if (isValid(m2wb.eInst.dst)) begin
                rf.wr(fromMaybe(?, m2wb.eInst.dst), m2wb.eInst.data);
            end

            csrf.wr(m2wb.eInst.iType == Csrw ? m2wb.eInst.csr : Invalid, m2wb.eInst.data);

            if (m2wb.eInst.iType == Unsupported) begin
                $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", m2wb.eInst.addr);
                $finish;
            end
        end else begin
            $display("[WB]-> (Drop) PC=%h", m2wb.eInst.addr);
        end

    endrule

    (* fire_when_enabled *)
    (* no_implicit_conditions *)
    rule canonicalizeRedirect(csrf.started);
        if (exeRedirect[1] matches tagged Valid .r) begin
            pcReg[1] <= r.nextPc;

            eEpoch <= !eEpoch;

            $display("[Redirect] PC: %h -> %h, epoch: %b -> %b", r.pc, r.nextPc, eEpoch, !eEpoch);
        end

        exeRedirect[1] <= Invalid;
    endrule


    method ActionValue#(CpuToHostData) cpuToHost;
        let ret <- csrf.cpuToHost;
        return ret;
    endmethod

    method Action hostToCpu(Bit#(32) startpc) if ( !csrf.started && memReady );
        csrf.start(0); // only 1 core, id = 0
	$display("Start at pc 200\n");
	$fflush(stdout);
        pcReg[0] <= startpc;
    endmethod

    interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
endmodule

