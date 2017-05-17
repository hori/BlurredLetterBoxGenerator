//
//  BlurredLetterBoxGenerator.swift
//  BlurredLetterBoxGenerator
//
//  Created by Yuki Horiguchi on 2017/05/15.
//  Copyright © 2017年 Yuki Horiguchi. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

@objc protocol BlurredLetterBoxGeneratorDelegate {
  func blurredLetterBoxGeneratorDidCompleteExportMovie() -> Void
  func blurredLetterBoxGeneratorDidFailExportMovie() -> Void
  @objc optional func blurredLetterBoxGeneratorExportProgress(_ progress: Float) -> Void
}

class BlurredLetterBoxGenerator {

  var asset: AVAsset
  var delegate: BlurredLetterBoxGeneratorDelegate?
  
  fileprivate var exportSession: AVAssetExportSession?
  fileprivate weak var observeExportProgressTimer: Timer?
  
  init(_ asset: AVAsset) {
    self.asset = asset
  }
  
  func export(to url: URL, outputSize: CGSize, timeRange: CMTimeRange? = nil) {
    guard let videoTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first,
          let videoSize = videoSize() else {
      delegate?.blurredLetterBoxGeneratorDidFailExportMovie()
      return
    }
    
    let trimTimeRange = CMTimeRange.init(start: timeRange?.start ?? kCMTimeZero, duration: timeRange?.end ?? asset.duration)

    let mixComposition = AVMutableComposition()

//    let filter = CIFilter(name: "CIGaussianBlur")!
//    filter.setValue(100.0, forKey: kCIInputRadiusKey)
//    let blurredLayer = CALayer()
//    blurredLayer.frame = CGRect.init(origin: .zero, size: outputSize)
//    blurredLayer.filters = [filter]

//    let filter = CIFilter(name: "CIGaussianBlur")!
//    let blurredVideoComposition = AVMutableVideoComposition.init(asset: mixComposition, applyingCIFiltersWithHandler: { request in
//      let source = request.sourceImage.clampingToExtent()
//      filter.setValue(source, forKey: kCIInputImageKey)
//      filter.setValue(100.0, forKey: kCIInputRadiusKey)
//      let output = filter.outputImage!
//      request.finish(with: output, context: nil)
//    })

//    let blurredAnimationTool = AVVideoCompositionCoreAnimationTool.init(additionalLayer: blurredLayer, asTrackID: 2)
//    let blurredAnimationTool = AVVideoCompositionCoreAnimationTool.init(postProcessingAsVideoLayer: blurredLayer, in: blurredLayer)
//    blurredVideoComposition.animationTool = blurredAnimationTool

    let videoComposition = AVMutableVideoComposition()
    videoComposition.frameDuration = videoTrack.minFrameDuration
    videoComposition.renderSize = outputSize
    
    // CompositionTrack
    let fgTrack: AVMutableCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: 1)
    let bgTrack: AVMutableCompositionTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: 2)

    do {
      try fgTrack.insertTimeRange(trimTimeRange, of: videoTrack, at: kCMTimeZero)
      try bgTrack.insertTimeRange(trimTimeRange, of: videoTrack, at: kCMTimeZero)
    } catch {
      delegate?.blurredLetterBoxGeneratorDidFailExportMovie()
      return
    }
    
    // LayerInstructions
    let fgLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: fgTrack)
    let bgLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: bgTrack)
    
    // Transform
    let viewW: CGFloat
    let viewH: CGFloat
    switch asset.videoOrientation(){
    case .portraitUpsideDown, .portrait:
      viewW = videoSize.height
      viewH = videoSize.width
      
    case .landscapeLeft, .landscapeRight:
      viewW = videoSize.width
      viewH = videoSize.height
      
    default:
      viewW = videoSize.width
      viewH = videoSize.height
    }
    
    let wph = viewW / viewH
    let OutputWph = outputSize.width / outputSize.height

    let fgScale: CGFloat
    let bgScale: CGFloat
    let fgOffsetX: CGFloat
    let fgOffsetY: CGFloat
    let bgOffsetX: CGFloat
    let bgOffsetY: CGFloat
    if wph > OutputWph {
      // Letterbox is Top & Bottom
      fgScale = outputSize.width / viewW
      bgScale = outputSize.height / viewH
      fgOffsetX = 0
      fgOffsetY = (outputSize.height - (viewH * fgScale)) / 2
      bgOffsetX = (outputSize.width - (viewW * bgScale)) / 2
      bgOffsetY = 0
    } else {
      // Letterbox is Left & Right
      fgScale = outputSize.height / viewH
      bgScale = outputSize.width / viewW
      fgOffsetX = (outputSize.width - (viewW * fgScale)) / 2
      fgOffsetY = 0
      bgOffsetX = 0
      bgOffsetY = (outputSize.height - (viewH * bgScale)) / 2
    }

    let t = videoTransform()
    
    let fgTScale = CGAffineTransform(scaleX: fgScale, y: fgScale)
    let bgTScale = CGAffineTransform(scaleX: bgScale, y: bgScale)
    let fgTMove = CGAffineTransform(translationX: fgOffsetX, y: fgOffsetY)
    let bgTMove = CGAffineTransform(translationX: bgOffsetX, y: bgOffsetY)

    let fgTransform = t.concatenating(fgTScale).concatenating(fgTMove)
    let bgTransform = t.concatenating(bgTScale).concatenating(bgTMove)

    // Add Transfrom
    fgLayerInstruction.setTransform(fgTransform, at: kCMTimeZero)
    bgLayerInstruction.setTransform(bgTransform, at: kCMTimeZero)
    
    // Opacity
    bgLayerInstruction.setOpacity(0.2, at: kCMTimeZero)

    // VideoInstruction
    let videoInstruction = AVMutableVideoCompositionInstruction()
    videoInstruction.timeRange = CMTimeRange.init(start: kCMTimeZero, duration: trimTimeRange.duration)

    // Connect Instructions
    fgLayerInstruction.trackID = 1
    bgLayerInstruction.trackID = 2
    videoInstruction.layerInstructions = [fgLayerInstruction, bgLayerInstruction]
    videoComposition.instructions = [videoInstruction]

    // Export
    exportSession = AVAssetExportSession.init(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
    exportSession?.outputURL = url
    exportSession?.outputFileType = AVFileTypeMPEG4
    exportSession?.videoComposition = videoComposition
    
    observeExportProgressTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(observeExportProgress(_:)), userInfo: nil, repeats: true)
    
    exportSession?.exportAsynchronously { [weak self] in
      self?.observeExportProgressTimer?.invalidate()
      self?.delegate?.blurredLetterBoxGeneratorDidCompleteExportMovie()
    }
    
  }
  
  fileprivate func videoSize() -> CGSize? {
    guard let track = asset.tracks(withMediaType: AVMediaTypeVideo).first else { return nil }
    return track.naturalSize
  }
  
  fileprivate func videoTransform() -> CGAffineTransform {
    guard let track = asset.tracks(withMediaType: AVMediaTypeVideo).first else { return CGAffineTransform() }
    let transform = track.preferredTransform
    return transform
  }
  
  @objc fileprivate func observeExportProgress(_ timer: Timer) {
    guard let progress = exportSession?.progress else { return }
    guard !(progress.isNaN) else { return }
    delegate?.blurredLetterBoxGeneratorExportProgress?(progress)
  }
  
  fileprivate func blurrdThumbnail(size: CGSize) -> UIImage {
    let generator = AVAssetImageGenerator(asset: asset)
    let cgimage: CGImage

    do {
      cgimage = try generator.copyCGImage(at: kCMTimeZero, actualTime: nil)
    } catch {
      return blankImage(size)
    }
    
    let image = UIImage(cgImage: cgimage)
    
    let outputWidthRatio = size.width / size.height
    let imageWidthRatio = image.size.width / image.size.height
    var drawSize: CGSize = size
    var drawPoint: CGPoint = .zero
    if outputWidthRatio < imageWidthRatio {
      // OutputImage is longer verticaly
      drawSize = CGSize(width: imageWidthRatio * size.height, height: size.height)
      drawPoint = CGPoint(x: (size.width - drawSize.width) / 2, y: 0)
    } else {
      // OutputImage is longer horizontally
      drawSize = CGSize(width: size.width, height: size.width / imageWidthRatio)
      drawPoint = CGPoint(x: 0, y: (size.height - drawSize.height) / 2)
    }
    
    UIGraphicsBeginImageContext(size)
    image.draw(in: CGRect(origin: drawPoint, size: drawSize) )
    let cloppedImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()

    let blurFilter = CIFilter.init(name: "CIGaussianBlur")
    blurFilter?.setValue(cloppedImage.ciImage, forKey: kCIInputImageKey)
    blurFilter?.setValue(20, forKey: kCIInputRadiusKey)

    if let ciimage = blurFilter?.outputImage {
      return UIImage(ciImage: ciimage)
    } else {
      return blankImage(size)
    }
  }
  
  fileprivate func blankImage(_ size: CGSize, color: UIColor = .black) -> UIImage {
    UIGraphicsBeginImageContext(size)
    let context = UIGraphicsGetCurrentContext()!
    context.setFillColor(UIColor.black.cgColor)
    context.fill(CGRect(origin: .zero, size: size))
    let blankImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return blankImage
  }
}

extension AVAsset {
  
  func videoOrientation() -> UIInterfaceOrientation {
    var orientation: UIInterfaceOrientation = .unknown
    let tracks :[AVAssetTrack] = self.tracks(withMediaType: AVMediaTypeVideo)
    if let videoTrack = tracks.first {
      let t = videoTrack.preferredTransform
      if (t.a == 0 && t.b == 1.0 && t.d == 0) {
        orientation = .portrait
      }
      else if (t.a == 0 && t.b == -1.0 && t.d == 0) {
        orientation = .portraitUpsideDown
      }
      else if (t.a == 1.0 && t.b == 0 && t.c == 0) {
        orientation = .landscapeRight
      }
      else if (t.a == -1.0 && t.b == 0 && t.c == 0) {
        orientation = .landscapeLeft
      }
    }
    return orientation
  }
}
