import Foundation
import Accelerate

class FFTAnalyzer {
    private let fftSize: Int
    private let log2n: vDSP_Length
    private let windowSize: vDSP_Length
    private let fftSetup: FFTSetup
    
    private var window: [Float]
    private var windowedBuffer: [Float]
    
    init(fftSize: Int = 1024) {
        self.fftSize = fftSize
        self.log2n = vDSP_Length(log2(Float(fftSize)))
        self.windowSize = vDSP_Length(fftSize)
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        
        self.window = [Float](repeating: 0, count: fftSize)
        self.windowedBuffer = [Float](repeating: 0, count: fftSize)
        
        vDSP_hann_window(&window, windowSize, Int32(vDSP_HANN_NORM))
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    func computeFFT(buffer: UnsafePointer<Float>) -> [Float] {
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        
        vDSP_vmul(buffer, 1, window, 1, &windowedBuffer, 1, windowSize)
        
        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)
        
        realp.withUnsafeMutableBufferPointer { realpPtr in
            imagp.withUnsafeMutableBufferPointer { imagpPtr in
                var splitComplex = DSPSplitComplex(realp: realpPtr.baseAddress!, imagp: imagpPtr.baseAddress!)
                
                windowedBuffer.withUnsafeBytes { ptr in
                    let bound = ptr.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(bound.baseAddress!, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                }
                
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                
                vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))
            }
        }
        
        // Normalize
        var scale = Float(1.0 / Float(fftSize))
        var normalized = [Float](repeating: 0, count: fftSize / 2)
        vDSP_vsmul(&magnitudes, 1, &scale, &normalized, 1, vDSP_Length(fftSize / 2))
        
        return normalized
    }
}
