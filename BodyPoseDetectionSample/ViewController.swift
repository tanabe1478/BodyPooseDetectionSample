//
//  ViewController.swift
//  BodyPoseDetectionSample
//
//  Created by tanabe.nobuyuki on 2020/12/06.
//

import UIKit
import Vision

class ViewController: UIViewController {
    // MARK: Internals
    @IBOutlet weak var previewImageView: UIImageView!
    
    // MARK: Privates
    private let videoCapture = VideoCapture()
    private var currentFrame: CGImage?
    private var imageSize = CGSize.zero
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        videoCapture.setUpAVCapture(completion: handleSetUpCompletion(_:))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        videoCapture.stopCapturing() {
            super.viewWillDisappear(animated)
        }
    }
    
}



// MARK: Vision
extension ViewController {
    func estimate(from cgImage: CGImage) {
        imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNDetectHumanBodyPoseRequest(completionHandler: handleBodyPoseDetection)
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("Request cannot perform because \(error)")
        }
    }
    
    
    func handleBodyPoseDetection(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRecognizedPointsObservation] else { return }
        
        if observations.count == 0 {
            guard let currentFrame = currentFrame else { return }
            let image = UIImage(cgImage: currentFrame)
            DispatchQueue.main.async {
                self.previewImageView.image = image
            }
        } else {
            observations.forEach { processObservation($0) }
        }
    }
    
    func processObservation(_ observation: VNRecognizedPointsObservation) {
        guard let recognizedPoints =
                try? observation.recognizedPoints(forGroupKey: .all) else {
            return
        }
        
        let imagePoints: [CGPoint] = recognizedPoints.values.compactMap {
            guard $0.confidence > 0 else { return nil}
            return VNImagePointForNormalizedPoint($0.location, Int(imageSize.width), Int(imageSize.height))
        }
        
        let image = currentFrame?.drawPoints(points: imagePoints)
        DispatchQueue.main.async {
            self.previewImageView.image = image
        }
    }
    
    
}






// MARK: Conform VideoCaptureDelegate
extension ViewController: VideoCaptureDelegate {
    func videoCapture(_ videoCapture: VideoCapture, didCaptureFrame image: CGImage?) {
        guard let image = image else {
            print("Can not captured")
            return
        }
        currentFrame = image
        estimate(from: image)
    }
}

// MARK: Private methods
private extension ViewController {
    func handleSetUpCompletion(_ error: Error?) {
        guard let error = error else {
            videoCapture.delegate = self
            videoCapture.startCapturing()
            return
        }
        print("Error詳細: \(error)")
    }
}

// MARK: Private extension of CGImage
private extension CGImage {
    func drawPoints(points:[CGPoint]) -> UIImage? {
        
        let cntx = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: bitsPerComponent , bytesPerRow: 0, space: colorSpace ?? CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        cntx?.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        for point in points {
            cntx?.setFillColor(red: 1, green: 0, blue: 1, alpha: 1)
            cntx?.addArc(center: point, radius: 4, startAngle: 0, endAngle: CGFloat(2*Double.pi), clockwise: false)
            cntx?.drawPath(using: .fill)
        }
        let _cgim = cntx?.makeImage()
        if let cgi = _cgim {
            let img = UIImage(cgImage: cgi)
            return img
        }
        return nil
    }
}

