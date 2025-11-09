import AVFoundation
import Accelerate

final class AudioResampler16k {
    private let targetASBD: AudioStreamBasicDescription
    private let converter: AVAudioConverter

    init?(sourceFormat: AVAudioFormat? = nil) {
        // Target: mono, 16 kHz, Float32
        var asbd = AudioStreamBasicDescription(
            mSampleRate: 16000,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        self.targetASBD = asbd
        guard let target = AVAudioFormat(streamDescription: &asbd) else { return nil }

        // We’ll create the converter lazily per input format at first call.
        // Placeholder—will be replaced in toMono16k when we know input format.
        self.converter = AVAudioConverter(from: target, to: target)! // dummy
    }

    /// Convert any mic buffer → [Float] mono @16k. Returns nil on failure.
    func toMono16k(buffer: AVAudioPCMBuffer) -> [Float]? {
        let inFmt  = buffer.format
        var asbd = targetASBD
        guard let outFmt = AVAudioFormat(streamDescription: &asbd) else { return nil }

        // If input already mono/16k Float32, fast-path extract
        if inFmt.sampleRate == 16000,
           inFmt.channelCount == 1,
           inFmt.commonFormat == .pcmFormatFloat32
        {
            let n = Int(buffer.frameLength)
            let ptr = buffer.floatChannelData![0]
            return Array(UnsafeBufferPointer(start: ptr, count: n))
        }

        // Build converter on the fly
        guard let conv = AVAudioConverter(from: inFmt, to: outFmt) else { return nil }
        conv.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Normal

        // Prepare input block
        var inputConsumed = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            inputConsumed = true
            return buffer
        }

        // Allocate output
        let outFrames = AVAudioFrameCount( max(1, Int(Double(buffer.frameLength) * (16000.0 / inFmt.sampleRate)) ) )
        guard let outBuf = AVAudioPCMBuffer(pcmFormat: outFmt, frameCapacity: outFrames) else { return nil }

        do {
            var error: NSError?
            let status = conv.convert(to: outBuf, error: &error, withInputFrom: inputBlock)
            guard status == .haveData || status == .inputRanDry else { return nil }
            outBuf.frameLength = min(outBuf.frameLength, outBuf.frameCapacity)
            let n = Int(outBuf.frameLength)
            let ptr = outBuf.floatChannelData![0]
            return Array(UnsafeBufferPointer(start: ptr, count: n))
        }
    }
}
