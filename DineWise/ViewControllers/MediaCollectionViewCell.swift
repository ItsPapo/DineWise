//
//  MediaCollectionViewCell.swift
//  DineWise
//
//  Created by Muhammad Mahad on 2025-03-22.
//

import UIKit
import AVFoundation

import UIKit
import AVFoundation

class MediaCollectionViewCell: UICollectionViewCell {

    @IBOutlet var imageView: UIImageView!
    @IBOutlet var videoView: UIView!

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var videoURL: URL?

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        imageView.isHidden = false
        videoView.isHidden = true

        pauseVideo()
        removePlayerLayer()
        player = nil
        videoURL = nil

        // Remove previous gestures
        if let gestures = videoView.gestureRecognizers {
            for gesture in gestures {
                videoView.removeGestureRecognizer(gesture)
            }
        }
    }

    // MARK: - Configure for Local Image
    func configureImage(fileName: String) {
        imageView.isHidden = false
        videoView.isHidden = true

        if let image = UIImage(named: fileName) {
            imageView.image = image
        } else if let path = Bundle.main.path(forResource: fileName, ofType: nil),
                  let image = UIImage(contentsOfFile: path) {
            imageView.image = image
        } else {
            imageView.image = UIImage(named: "placeholder")
        }
    }

    // MARK: - Configure for Video (Bundle OR Documents)
    func configureVideo(fileName: String) {
        imageView.isHidden = true
        videoView.isHidden = false

        removePlayerLayer()
        player = nil

        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDir.appendingPathComponent(fileName)

        var finalURL: URL? = nil

        if fileManager.fileExists(atPath: fileURL.path) {
            finalURL = fileURL
        } else {
            // Fallback to bundle
            let name = fileName.replacingOccurrences(of: ".mp4", with: "").replacingOccurrences(of: ".mov", with: "")
            finalURL = Bundle.main.url(forResource: name, withExtension: "mp4") ??
                       Bundle.main.url(forResource: name, withExtension: "mov")
        }

        guard let videoURL = finalURL else {
            print("⚠️ Could not load video: \(fileName)")
            return
        }

        self.videoURL = videoURL
        player = AVPlayer(url: videoURL)

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = videoView.bounds
        playerLayer?.videoGravity = .resizeAspectFill

        if let layer = playerLayer {
            videoView.layer.addSublayer(layer)
        }

        // Add tap-to-play/pause gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleVideoTap))
        videoView.isUserInteractionEnabled = true
        videoView.addGestureRecognizer(tap)
    }

    @objc private func handleVideoTap() {
        if player?.timeControlStatus == .playing {
            player?.pause()
        } else {
            player?.play()
        }
    }

    func playVideo() {
        print("▶️ Playing video")
        player?.play()
    }

    func pauseVideo() {
        print("⏸️ Pausing video")
        player?.pause()
    }

    private func removePlayerLayer() {
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }
}
