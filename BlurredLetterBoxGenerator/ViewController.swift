//
//  ViewController.swift
//  BlurredLetterBoxGenerator
//
//  Created by Yuki Horiguchi on 2017/05/15.
//  Copyright © 2017年 Yuki Horiguchi. All rights reserved.
//

import UIKit
import AssetsLibrary
import AVFoundation

class ViewController: UIViewController {

  @IBOutlet weak var playerView: AVPlayerView!
  fileprivate let imagePickerController = UIImagePickerController()
  fileprivate let fileManager = VideoFileManager.shared
  fileprivate var playerItem: AVPlayerItem?
  fileprivate var player: AVPlayer?

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func selectVideo(_ sender: AnyObject) {
    playerView.player = nil
    player = nil
    playerItem = nil
    
    imagePickerController.sourceType = .photoLibrary
    imagePickerController.delegate = self
    imagePickerController.mediaTypes = ["public.movie"]
    imagePickerController.allowsEditing = false
    present(imagePickerController, animated: true, completion: nil)
  }

}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
    picker.dismiss(animated: true, completion: nil)
  }
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    picker.dismiss(animated: true, completion: nil)
    guard let url = info["UIImagePickerControllerReferenceURL"] as? URL else { return }
    
    let startTime = CMTime.init(seconds: 1.0, preferredTimescale: Int32(NSEC_PER_SEC))
    let endTime = CMTime.init(seconds: 5.0, preferredTimescale: Int32(NSEC_PER_SEC))
    let timeRange = CMTimeRange.init(start: startTime, end: endTime)
    fileManager.remove(to: .normarized)
    let generator = BlurredLetterBoxGenerator(AVAsset(url: url))
    generator.delegate = self
    generator.export(to: fileManager.url(of: .normarized), outputSize: CGSize.init(width: 540, height: 960), timeRange: timeRange)
  }
}

extension ViewController: BlurredLetterBoxGeneratorDelegate {

  func blurredLetterBoxGeneratorDidCompleteExportMovie() {
    print("complete")
    let asset = AVAsset(url: fileManager.url(of: .normarized))
    playerItem = AVPlayerItem(asset: asset)
    player = AVPlayer(playerItem: playerItem)
    playerView.player = player
    player?.play()
  }
  
  func blurredLetterBoxGeneratorDidFailExportMovie() {
    print("failed")
  }
  
  func blurredLetterBoxGeneratorExportProgress(_ progress: Float) {
    print(progress)
  }
}
