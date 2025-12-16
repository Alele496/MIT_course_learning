
import ClientServer::*;
import GetPut::*;

import AudioProcessorTypes::*;
import Chunker::*;
import FFT::*;
import FIRFilter::*;
import Splitter::*;

import FilterCoefficients::*;
import FixedPoint::*;

import ToMP::*;
import FromMP::*;
import OverSampler::*;
import Overlayer::*;
import PitchAdjust::*;
import Vector::*;



(* synthesize *)
module mkAudioPipelineFIR(AudioProcessor);
    AudioProcessor fir <- mkFIRFilter(c);
    return fir;
endmodule

(* synthesize *)
module mkAudioPipelineFFT(FFT#(N, FixedPoint#(ISIZE, FSIZE)));
    FFT#(N, FixedPoint#(ISIZE, FSIZE)) fft <- mkFFT();
    return fft;
endmodule

(* synthesize *)
module mkAudioPipelineToMP(ToMP#(N, ISIZE, FSIZE, PSIZE));
    ToMP#(N, ISIZE, FSIZE, PSIZE) tomp <- mkToMP();
    return tomp;
endmodule

(* synthesize *)
module mkAudioPipelinePitchAdjust(SettablePitchAdjust#(N, ISIZE, FSIZE, PSIZE));
    // PitchAdjust#(N, ISIZE, FSIZE, PSIZE) pitchAdjust <- mkPitchAdjust(valueOf(S), fromInteger(valueOf(FACTOR)));
    SettablePitchAdjust#(N, ISIZE, FSIZE, PSIZE) pitchAdjust <- mkPitchAdjust(valueOf(S));   // exposes the setfactor outside
    return pitchAdjust;
endmodule

(* synthesize *)
module mkAudioPipelineFromMP(FromMP#(N, ISIZE, FSIZE, PSIZE));
    FromMP#(N, ISIZE, FSIZE, PSIZE) frommp <- mkFromMP();
    return frommp;
endmodule

(* synthesize *)
module mkAudioPipelineIFFT(FFT#(N, FixedPoint#(ISIZE, FSIZE)));
    FFT#(N, FixedPoint#(ISIZE, FSIZE)) ifft <- mkIFFT();
    return ifft;
endmodule

(* synthesize *)
module mkAudioPipeline(AudioProcessor);

    // AudioProcessor fir <- mkFIRFilter();
    AudioProcessor fir <- mkAudioPipelineFIR();
    Chunker#(S, Sample) chunker <- mkChunker();
    OverSampler#(S, N, Sample) oversampler <- mkOverSampler(replicate(0));
    FFT#(N, FixedPoint#(ISIZE, FSIZE)) fft <- mkAudioPipelineFFT();
    ToMP#(N, ISIZE, FSIZE, PSIZE) tomp <- mkAudioPipelineToMP();
    SettablePitchAdjust#(N, ISIZE, FSIZE, PSIZE) settablePitchAdjust <- mkAudioPipelinePitchAdjust();
    PitchAdjust#(N, ISIZE, FSIZE, PSIZE) pitchAdjust = settablePitchAdjust.adjust;

    FromMP#(N, ISIZE, FSIZE, PSIZE) frommp <- mkAudioPipelineFromMP();
    FFT#(N, FixedPoint#(ISIZE, FSIZE)) ifft <- mkAudioPipelineIFFT();
    Overlayer#(N, S, Sample) overlayer <- mkOverlayer(replicate(0));
    Splitter#(S, Sample) splitter <- mkSplitter();

    rule fir_to_chunker (True);
        let x <- fir.getSampleOutput();
        chunker.request.put(x);
    endrule

    rule chunker_to_oversampler (True);
        let x <- chunker.response.get();
        oversampler.request.put(x);
    endrule

    rule oversampler_to_fft (True);
        let x <- oversampler.response.get();
        Vector#(N, ComplexSample) complex_data = replicate(0);
        for (Integer i = 0; i < valueOf(N); i = i + 1) begin
            complex_data[i] = tocmplx(x[i]); 
        end
        fft.request.put(complex_data);
    endrule

    rule fft_to_toMP (True);
        let x <- fft.response.get();
        tomp.request.put(x);
    endrule

    rule toMP_to_pitchAdjust (True);
        let x <- tomp.response.get();
        pitchAdjust.request.put(x);
    endrule

    rule pitchAdjust_to_frommp (True);
        let x <- pitchAdjust.response.get();
        frommp.request.put(x);
    endrule

    rule frommp_to_ifft (True);
        let x <- frommp.response.get();
        ifft.request.put(x);
    endrule

    rule ifft_to_overlayer (True);
        let x <- ifft.response.get();
        Vector#(N, Sample) data = replicate(0);
        for (Integer i = 0; i < valueOf(N); i = i + 1) begin
            data[i] = frcmplx(x[i]); 
        end
        overlayer.request.put(data);
    endrule

    rule overlayer_to_splitter (True);
        let x <- overlayer.response.get();
        splitter.request.put(x);
    endrule
    
    method Action putSampleInput(Sample x);
        fir.putSampleInput(x);
    endmethod

    method ActionValue#(Sample) getSampleOutput();
        let x <- splitter.response.get();
        return x;
    endmethod

    method Action setFactor(FixedPoint#(ISIZE, FSIZE) factor);
        settablePitchAdjust.setFactor.put(factor);
    endmethod

endmodule

