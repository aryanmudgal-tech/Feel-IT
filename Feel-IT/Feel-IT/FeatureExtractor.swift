import Foundation
import Accelerate

final class FeatureExtractor {
    // Tunables
    private let sampleRate: Float = 16000
    private let fftSize: Int = 1024            // 64 ms @16k
    private let hopSize: Int = 256             // 16 ms hop
    private let melBins: Int = 64
    private let fmin: Float = 50
    private let fmax: Float = 8000

    // Precomputed
    private let window: [Float]
    private var fftSetup: FFTSetup?
    private let melFilter: [[Float]]           // [melBins][fftBins]
    private let fftBins: Int

    init() {
        self.window = vDSP.window(ofType: Float.self,
                                  usingSequence: .hanningDenormalized,
                                  count: fftSize,
                                  isHalfWindow: false)
        self.fftBins = fftSize/2 + 1
        self.fftSetup = vDSP_create_fftsetup(vDSP_Length(log2f(Float(fftSize))), FFTRadix(kFFTRadix2))
        self.melFilter = MelFilterbank.build(
            samplerate: sampleRate,
            nFft: fftSize,
            nMels: melBins,
            fmin: fmin,
            fmax: fmax
        )
    }

    deinit {
        if let s = fftSetup { vDSP_destroy_fftsetup(s) }
    }

    /// Input: mono float PCM @16k. Typical length: ~0.8s → 12800 samples.
    /// Output: 128-D embedding (mean(64) + std(64)), L2-normalized.
    func embed(pcm xIn: [Float]) -> [Float] {
        guard xIn.count >= fftSize else {
            // zero-pad to fftSize to avoid edge cases
            var tmp = xIn + [Float](repeating: 0, count: max(0, fftSize - xIn.count))
            return embed(pcm: tmp)
        }

        // Frame signal
        var frames: [[Float]] = []
        frames.reserveCapacity(max(1, (xIn.count - fftSize) / hopSize + 1))
        var i = 0
        while i + fftSize <= xIn.count {
            var frame = Array(xIn[i..<i+fftSize])
            vDSP.multiply(frame, window, result: &frame)
            frames.append(frame)
            i += hopSize
        }

        // STFT power → mel → log
        var melPerFrame: [[Float]] = []
        melPerFrame.reserveCapacity(frames.count)

        var real = [Float](repeating: 0, count: fftSize/2)
        var imag = [Float](repeating: 0, count: fftSize/2)
        var split = DSPSplitComplex(realp: &real, imagp: &imag)

        for var frame in frames {
            // Real-to-complex in-place FFT using vDSP_fft_zrip expects split-complex.
            // Convert real time-domain to split-complex frequency domain.
            frame.withUnsafeMutableBufferPointer { buf in
                buf.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize/2) { complexPtr in
                    // pack real signal into split form
                    vDSP_ctoz(complexPtr, 2, &split, 1, vDSP_Length(fftSize/2))
                }
            }
            // FFT
            vDSP_fft_zrip(fftSetup!, &split, 1, vDSP_Length(log2f(Float(fftSize))), FFTDirection(FFT_FORWARD))

            // Scale (vDSP’s zrip is unscaled; scale by 0.5)
            var scale: Float = 0.5
            vDSP_vsmul(split.realp, 1, &scale, split.realp, 1, vDSP_Length(fftSize/2))
            vDSP_vsmul(split.imagp, 1, &scale, split.imagp, 1, vDSP_Length(fftSize/2))

            // Power spectrum (magnitude^2), rebuild DC/Nyquist bins
            var power = [Float](repeating: 0, count: fftBins)
            power[0] = split.realp[0]*split.realp[0]      // DC
            for k in 1..<(fftSize/2) {
                let re = split.realp[k], im = split.imagp[k]
                power[k] = re*re + im*im
            }
            power[fftBins - 1] = split.imagp[0]*split.imagp[0] // Nyquist

            // Apply mel filters
            var mel = [Float](repeating: 0, count: melBins)
            for m in 0..<melBins {
                mel[m] = vDSP.dot(power, melFilter[m])
            }

            // log-energy (natural log)
            var eps: Float = 1e-6
            vDSP.add(eps, mel, result: &mel)
            var count32 = Int32(mel.count)
            vvlogf(&mel, mel, &count32)

            melPerFrame.append(mel)
        }

        // Aggregate across time: mean + std => 128 dims
        var mean = [Float](repeating: 0, count: melBins)
        var std  = [Float](repeating: 0, count: melBins)
        reduceColumnsMeanStd(melPerFrame, &mean, &std)

        var v = mean + std
        // L2 normalize
        var norm: Float = 0
        vDSP_svesq(v, 1, &norm, vDSP_Length(v.count))
        norm = sqrtf(norm) + 1e-9
        vDSP.divide(v, norm, result: &v)
        return v
    }

    // Efficient mean/std over list-of-rows (frames x melBins)
    private func reduceColumnsMeanStd(_ rows: [[Float]], _ mean: inout [Float], _ std: inout [Float]) {
        guard !rows.isEmpty else { return }
        let T = rows.count
        let D = rows[0].count
        var sum = [Float](repeating: 0, count: D)
        var sumsq = [Float](repeating: 0, count: D)

        for r in rows {
            vDSP.add(sum, r, result: &sum)
            var r2 = [Float](repeating: 0, count: D)
            vDSP.multiply(r, r, result: &r2)
            vDSP.add(sumsq, r2, result: &sumsq)
        }
        var invT = 1.0 / Float(T)
        vDSP.multiply(invT, sum, result: &mean)

        // std = sqrt(E[x^2] - (E[x])^2)
        var ex2 = [Float](repeating: 0, count: D)
        vDSP.multiply(invT, sumsq, result: &ex2)

        var mean2 = [Float](repeating: 0, count: D)
        vDSP.multiply(mean, mean, result: &mean2)

        var varv = [Float](repeating: 0, count: D)
        vDSP.subtract(mean2, ex2, result: &varv) // NOTE: ex2 - mean^2; negative clamp
        // Clamp tiny negatives to zero
        for i in 0..<D { varv[i] = max(0, ex2[i] - mean2[i]) }
        vvsqrtf(&std, varv, [Int32(D)])
    }
}

// MARK: - Mel filterbank
enum MelFilterbank {
    // Returns [nMels][nFft/2 + 1]
    static func build(samplerate: Float, nFft: Int, nMels: Int, fmin: Float, fmax: Float) -> [[Float]] {
        let nFftBins = nFft/2 + 1
        let fMin = max(0, fmin)
        let fMax = min(samplerate/2, fmax)
        // Mel scale helpers
        func hz2mel(_ f: Float) -> Float { 2595.0 * log10f(1 + f/700.0) }
        func mel2hz(_ m: Float) -> Float { 700.0 * (powf(10, m/2595.0) - 1) }

        let melMin = hz2mel(fMin), melMax = hz2mel(fMax)
        let melPoints = (0..<(nMels+2)).map { i in
            melMin + (Float(i) * (melMax - melMin) / Float(nMels + 1))
        }
        let hzPoints = melPoints.map(mel2hz)

        // Map center frequencies to FFT bin indices
        let bin = hzPoints.map { Int(roundf( Float(nFft) * $0 / samplerate )) }

        var filters = Array(repeating: Array(repeating: Float(0), count: nFftBins), count: nMels)
        for m in 1...nMels {
            let f_m_minus = bin[m-1]
            let f_m       = bin[m]
            let f_m_plus  = bin[m+1]
            if f_m_minus < f_m && f_m < f_m_plus {
                for k in f_m_minus..<f_m {
                    filters[m-1][k] = Float(k - f_m_minus) / Float(f_m - f_m_minus)
                }
                for k in f_m..<min(f_m_plus, nFftBins) {
                    filters[m-1][k] = Float(f_m_plus - k) / Float(f_m_plus - f_m)
                }
            }
        }
        return filters
    }
}
