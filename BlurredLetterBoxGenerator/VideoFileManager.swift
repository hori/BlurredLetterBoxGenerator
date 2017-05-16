//
//  VideoFileManager.swift
//  BlurredLetterBoxGenerator
//
//  Created by Yuki Horiguchi on 2017/05/15.
//  Copyright © 2017年 Yuki Horiguchi. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class VideoFileManager {
  
  enum FileName: String {
    case normarized = "normarized.mp4"
  }
  
  private let manager = FileManager.default
  
  static var shared: VideoFileManager = {
    return VideoFileManager()
  }()
  
  private init() {
  }
  
  func url(of fileName: FileName) -> URL {
    let dir: URL! = manager.urls(for: .documentDirectory, in: .userDomainMask).last
    let path = dir.appendingPathComponent(fileName.rawValue)
    return path.absoluteURL
  }
  
  func isExists(of fileName: FileName, checkValidation: Bool = false) -> Bool {
    if manager.fileExists(atPath: url(of: fileName).path){
      if !checkValidation {
        return true
      }
      if validVideo(of: fileName) {
        return true
      }
      return false
    } else {
      return false
    }
  }
  
  func remove(to fileName: FileName) {
    if isExists(of: fileName) {
      do {
        try manager.removeItem(atPath: url(of: fileName).path)
      } catch {
        print("anything happen")
      }
    }
  }
  
  func removeAllFiles() {
    remove(to: .normarized)
  }
  
  func validVideo(of fileName: FileName) -> Bool {
    let asset = AVURLAsset(url: url(of: fileName))
    guard let track = asset.tracks(withMediaType: AVMediaTypeVideo).first else { return false }
    return track.isPlayable
  }
  
}

