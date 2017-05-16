//
//  AVPlayerView.swift
//  BlurredLetterBoxGenerator
//
//  Created by Yuki Horiguchi on 2017/05/15.
//  Copyright © 2017年 Yuki Horiguchi. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class AVPlayerView: UIView {
  var player: AVPlayer? {
    get {
      return playerLayer.player
    }
    set {
      playerLayer.player = newValue
    }
  }
  
  var playerLayer: AVPlayerLayer {
    return layer as! AVPlayerLayer
  }
  
  override static var layerClass: AnyClass {
    return AVPlayerLayer.self
  }
}
