//
//  VideoCapture.swift
//  BodyPoseDetectionSample
//
//  Created by tanabe.nobuyuki on 2020/12/06.
//

import Foundation
import CoreVideo
import UIKit
import VideoToolbox
import AVFoundation

protocol VideoCaptureDelegate: AnyObject {
    func videoCapture(_ videoCapture: VideoCapture, didCaptureFrame image: CGImage?)
}

class VideoCapture: NSObject {
    enum VideoCaptureError: Error {
        case captureSessionIsMissing
        case invalidInput
        case invalidOutput
        case unknown
    }
    
    weak var delegate: VideoCaptureDelegate?
    
    let captureSession = AVCaptureSession()
    
    let videoOutput = AVCaptureVideoDataOutput()
    
    
    private(set) var cameraPosition = AVCaptureDevice.Position.back
    
    private let sessionQueue = DispatchQueue(label: "tanabe1478.pose-estimation")
    
    func setUpAVCapture(completion: @escaping (Error?) -> Void) {
        sessionQueue.async {
            do {
                try self.setUpAVCapture()
                DispatchQueue.main.async {
                    completion(nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(error)
                }
            }
        }
    }
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let delegate = delegate else { return }
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
        
        // ピクセルバッファのベースアドレスをロック
        guard CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == kCVReturnSuccess
            else { return }
        var image: CGImage?
        
        // 指定されたピクセルバッファを使用して、Core Graphicsのビットマップ画像またはイメージマスクを作成
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &image)
        
        // ピクセルバッファのベースアドレスをアンロック
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        DispatchQueue.main.sync {
            delegate.videoCapture(self, didCaptureFrame: image)
        }
    }
    
    func startCapturing(completion completionHandler: (() -> Void)? = nil) {
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
            
            if let completionHandler = completionHandler {
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        }
    }
    
    public func stopCapturing(completion completionHandler: (() -> Void)? = nil) {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            
            if let completionHandler = completionHandler {
                DispatchQueue.main.async {
                    completionHandler()
                }
            }
        }
    }
    
    
}

extension VideoCapture {
    
    private func setUpAVCapture() throws {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .vga640x480
        
        try setCaptureSessionInput()
        try setCaptureSessionOutput()
        
        captureSession.commitConfiguration()
    }
    
    private func setCaptureSessionInput() throws {
        guard let captureDevice = AVCaptureDevice.default(
                .builtInDualWideCamera,
            for: .video,
                position: cameraPosition) else {
            throw VideoCaptureError.invalidInput
        }
        
        captureSession.inputs.forEach { input in
            captureSession.removeInput(input)
        }
        
        guard let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            throw VideoCaptureError.invalidInput
        }
        
        guard captureSession.canAddInput(videoInput) else {
            throw VideoCaptureError.invalidInput
        }
        
        captureSession.addInput(videoInput)
    }
    
    private func setCaptureSessionOutput() throws {
        captureSession.outputs.forEach { output in
            captureSession.removeOutput(output)
        }
        
        let settings: [String: Any] = [
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        
        videoOutput.videoSettings = settings
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        
        captureSession.addOutput(videoOutput)
        
        if let connection = videoOutput.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}
