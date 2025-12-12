import FromMP::*;
import Vector::*;
import Complex::*;
import ComplexMP::*;
import FixedPoint::*;
import GetPut::*;
import ClientServer::*;

import FShow::*;

(* synthesize *)
module mkFromMPTest(Empty);

    FromMP#(8, 16, 16, 16) frommp <- mkFromMP();
    Reg#(Bit#(32)) state <- mkReg(0);

    // 辅助函数：创建 ComplexMP 值
    function ComplexMP#(16, 16, 16) mkComplexMP(Int#(32) mag_int, Int#(16) phase_int);
        FixedPoint#(16, 16) mag = unpack(pack(mag_int));
        return cmplxmp(mag, phase_int);
    endfunction

    // 准备测试向量：幅度为 sqrt(2) ≈ 92682，相位为 π/4 ≈ 8194
    // 对应直角坐标应为 (1.0, 1.0)
    ComplexMP#(16, 16, 16) testMP = mkComplexMP(92682, 8194);
    Vector#(8, ComplexMP#(16, 16, 16)) testVec = replicate(testMP);

    rule test_stage0(state == 0);
        $display("=== FromMP Test Started ===");
        $display("Sending test vector (magnitude=%d, phase=%d)...", 92682, 8194);
        frommp.request.put(testVec);
        state <= 1;
    endrule

    rule test_stage1(state == 1);
        let result <- frommp.response.get();
        $display("Received converted vector (rectangular coordinates):");

        // 将 FixedPoint 转换为 Int#(32) 表示（放大2^16倍）
        function Int#(32) fxptToInt(FixedPoint#(16,16) fx);
            Bit#(32) bits = pack(fx);
            return unpack(bits);
        endfunction

        for (Integer i = 0; i < 8; i = i + 1) begin
            let real_val = result[i].rel;
            let imag_val = result[i].img;
            Int#(32) real_int = fxptToInt(real_val);
            Int#(32) imag_int = fxptToInt(imag_val);
            $display("  Bin %0d: Real = %d, Imag = %d", 
                     i, real_int, imag_int);
        end

        // 期望值：1.0 在 FixedPoint#(16,16) 中为 65536
        Int#(32) expectedVal = 65536;  // 1.0 * 2^16
        
        // 获取第一个结果的实部和虚部
        Int#(32) real0_int = fxptToInt(result[0].rel);
        Int#(32) imag0_int = fxptToInt(result[0].img);

        // 计算误差
        Int#(32) realError = (real0_int > expectedVal) ? (real0_int - expectedVal) : (expectedVal - real0_int);
        Int#(32) imagError = (imag0_int > expectedVal) ? (imag0_int - expectedVal) : (expectedVal - imag0_int);

        // 设定误差容限（比 ToMP 测试稍大，因为两次转换会有累积误差）
        Int#(32) tolerance = 2000;  // 约 0.03 * 65536

        if ((realError < tolerance) && (imagError < tolerance)) begin
            $display("PASSED: Conversion is correct within tolerance");
            $display("  Real: got %d, expected %d, error %d", real0_int, expectedVal, realError);
            $display("  Imag: got %d, expected %d, error %d", imag0_int, expectedVal, imagError);
        end else begin
            $display("FAILED: Real error = %d (tolerance %d), Imag error = %d (tolerance %d)", 
                     realError, tolerance, imagError, tolerance);
        end
        
        state <= 2;
    endrule

    rule test_stage2 (state == 2);
        $display("=== FromMP Test Finished ===");
        $finish();
    endrule

endmodule