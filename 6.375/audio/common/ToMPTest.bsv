
import ToMP::*;
import Vector::*;
import Complex::*;
import ComplexMP::*;
import FixedPoint::*;
import GetPut::*;
import ClientServer::*;

import FShow::*;

(* synthesize *)
module mkToMPTest(Empty);

    ToMP#(8, 16, 16, 16) tomp <- mkToMP();
    Reg#(Bit#(32)) state <- mkReg(0);

    // 创建 FixedPoint#(16, 16) 的辅助函数 - 使用 Int#(32) 构造
    function FixedPoint#(16, 16) mkFixedPoint16(Int#(32) intVal);
        return unpack(pack(intVal));
    endfunction

    function Complex#(FixedPoint#(16, 16)) makeComplex(FixedPoint#(16, 16) real_val, FixedPoint#(16, 16) imag_val);
        return cmplx(real_val, imag_val);
    endfunction

    // 创建测试向量：每个元素都是 (1.0, 1.0)
    // 1.0 在 FixedPoint#(16,16) 中的表示：1 * 2^16 = 65536
    Int#(32) one_int = 65536;
    FixedPoint#(16, 16) one = mkFixedPoint16(one_int);  // 1.0
    Vector#(8, Complex#(FixedPoint#(16, 16))) testVec = replicate(makeComplex(one, one));

    rule test_stage0(state == 0);
        $display("=== ToMP Test Started ===");
        $display("Sending test vector...");
        tomp.request.put(testVec);
        state <= 1;
    endrule

    rule test_stage1(state == 1);
        let result <- tomp.response.get();
        $display("Received converted vector:");

        // 将 FixedPoint 转换为 Int#(32) 表示（放大2^16倍）
        function Int#(32) fxptToInt(FixedPoint#(16,16) fx);
            Bit#(32) bits = pack(fx);
            return unpack(bits);
        endfunction

        for (Integer i = 0; i < 8; i = i + 1) begin
            let mag = result[i].magnitude;
            let phase = result[i].phase;
            Int#(32) mag_int = fxptToInt(mag);
            $display("  Bin %0d: Magnitude (int) = %d, Phase = %d", 
                     i, mag_int, phase);
        end

        // 期望的幅度整数表示：sqrt(2) * 2^16 ≈ 92681
        Int#(32) expectedMagInt = 92681;  // 1.41421356 * 65536 四舍五入
        Int#(16) expectedPhaseInt = 8192; // π/4 对应的相位整数

        // 获取第一个结果的幅度和相位
        Int#(32) mag0_int = fxptToInt(result[0].magnitude);
        Int#(16) phase0_int = result[0].phase;

        // 计算误差
        Int#(32) magError = (mag0_int > expectedMagInt) ? (mag0_int - expectedMagInt) : (expectedMagInt - mag0_int);
        Int#(16) phaseError = (phase0_int > expectedPhaseInt) ? (phase0_int - expectedPhaseInt) : (expectedPhaseInt - phase0_int);

        // 设定误差容限
        Int#(32) magTolerance = 655;  // 0.01 * 65536 ≈ 655
        Int#(16) phaseTolerance = 10;

        if ((magError < magTolerance) && (phaseError < phaseTolerance)) begin
            $display("PASSED: Conversion is correct within tolerance");
            $display("  Magnitude: got %d, expected %d, error %d", mag0_int, expectedMagInt, magError);
            $display("  Phase: got %d, expected %d, error %d", phase0_int, expectedPhaseInt, phaseError);
        end else begin
            $display("FAILED: Magnitude error = %d (tolerance %d), Phase error = %d (tolerance %d)", 
                     magError, magTolerance, phaseError, phaseTolerance);
        end
        
        state <= 2;
    endrule

    rule test_stage2 (state == 2);
        $display("=== ToMP Test Finished ===");
        $finish();
    endrule

endmodule