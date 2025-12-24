// TwoStageBTB.bsv
//
// This is a two stage(BTB) implementation of the RISC-V processor.

import Types::*;
import ProcTypes::*;
import CMemTypes::*;
import RFile::*;
import IMemory::*;
import DMemory::*;
import Decode::*;
import Exec::*;
import CsrFile::*;
import Vector::*;
import Fifo::*;
import Ehr::*;
import GetPut::*;

import Btb::*;


(* synthesize *)
module mkProc(Proc);
    Reg#(Addr) pc <- mkRegU;
    RFile      rf <- mkRFile;
    IMemory  iMem <- mkIMemory;
    DMemory  dMem <- mkDMemory;
    CsrFile  csrf <- mkCsrFile;

    Btb#(8) btb <- mkBtb();

    Reg#(Data) instReg <- mkRegU();
    Reg#(Addr) pcReg <- mkRegU();
    Reg#(Bool) validData <- mkReg(False);

    Reg#(Addr) predPcReg <- mkRegU();

    Bool memReady = iMem.init.done() && dMem.init.done();
    rule test (!memReady);
	    let e = tagged InitDone;
	    iMem.init.request.put(e);
	    dMem.init.request.put(e);
    endrule

    rule doProcess(csrf.started && memReady);
        // Fetch
        if (!validData)begin
            Data inst = iMem.req(pc);

            Addr btbPredPc = btb.predPc(pc);

            // Recoding
            instReg <= inst;
            pcReg <= pc;

            predPcReg <= btbPredPc;

            // Set state
            validData <= True;

            pc <= btbPredPc;
            $display("[Fetch] PC=%h, Inst=%h, BTBPred=%h", pc, inst, btbPredPc);

        end else begin

            Data inst = instReg;
            Addr currentPc = pcReg;

            // Decode
            DecodedInst dInst = decode(inst);

            // Trace-stdout
            $display("pc: %h inst: (%h) expanded:", pc, inst, showInst(inst));
            $fflush(stdout);


            // read general purpose register values 
            Data rVal1 = rf.rd1(fromMaybe(?, dInst.src1));
            Data rVal2 = rf.rd2(fromMaybe(?, dInst.src2));

            // read CSR values (for CSRR inst)
            Data csrVal = csrf.rd(fromMaybe(?, dInst.csr));

            // Addr predPc = currentPc + 4;
            Addr predPc = predPcReg;    // BTBpred vaule

            // execute
            ExecInst eInst = exec(dInst, rVal1, rVal2, currentPc, predPc, csrVal);  
		    // The fifth argument above is the predicted pc, to detect if it was mispredicted. 
		    // Since there is no branch prediction, this field is sent with a random value

            // memory
            if(eInst.iType == Ld) begin
                eInst.data <- dMem.req(MemReq{op: Ld, addr: eInst.addr, data: ?});
            end else if(eInst.iType == St) begin
                let d <- dMem.req(MemReq{op: St, addr: eInst.addr, data: eInst.data});
            end

            // check unsupported instruction at commit time. Exiting
            if(eInst.iType == Unsupported) begin
                $fwrite(stderr, "ERROR: Executing unsupported instruction at pc: %x. Exiting\n", pc);
                $finish;
            end

            // Branch prediction processing
            if (eInst.mispredict) begin
                pc <= eInst.addr;

                validData <= False;
                $display("pc: %h inst: (%h) expanded:", pc, inst, showInst(inst));
            end else begin
                // write back to reg file
                if(isValid(eInst.dst)) begin
                    rf.wr(fromMaybe(?, eInst.dst), eInst.data);
                end

                // CSR write for sending data to host & stats
                csrf.wr(eInst.iType == Csrw ? eInst.csr : Invalid, eInst.data);

                // Set state
                validData <= False;
                $display("pc: %h inst: (%h) expanded:", pc, inst, showInst(inst));
            end

            // branch jump
            if (eInst.brTaken && eInst.addr != currentPc + 4) begin
                btb.update(currentPc, eInst.addr);
            end

        end

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

        validData <= False;
    endmethod

    interface iMemInit = iMem.init;
    interface dMemInit = dMem.init;
endmodule

