
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


typedef 8 N;
typedef 2 S;
typedef 2 FACTOR;
typedef 16 ISIZE;
typedef 16 FSIZE;
typedef 16 PSIZE;

module mkAudioPipeline(AudioProcessor);

    // AudioProcessor fir <- mkFIRFilter();
    AudioProcessor fir <- mkFIRFilter(c);
    Chunker#(S, Sample) chunker <- mkChunker();
    OverSampler#(S, N, Sample) oversampler <- mkOverSampler(replicate(0));
    FFT#(N, FixedPoint#(ISIZE, FSIZE)) fft <- mkFFT();
    ToMP#(N, ISIZE, FSIZE, PSIZE) tomp <- mkToMP();
    PitchAdjust#(N, ISIZE, FSIZE, PSIZE) pitchAdjust <- mkPitchAdjust(valueOf(S), fromInteger(valueOf(FACTOR)));
    FromMP#(N, ISIZE, FSIZE, PSIZE) frommp <- mkFromMP();
    FFT#(N, FixedPoint#(ISIZE, FSIZE)) ifft <- mkIFFT();
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

endmodule

