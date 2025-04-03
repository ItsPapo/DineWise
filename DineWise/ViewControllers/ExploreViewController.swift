//
//  ExploreViewController.swift
//  DineWise
//
//  Created by Muhammad Mahad on 2025-03-22.
//

import UIKit
import AVKit

class ExploreViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet var collectionView: UICollectionView!
    
    var mediaItems: [Media] = [] // Stores local images & videos

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false

        loadLocalMedia()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadLocalMedia()
    }

    // MARK: - Load Local + User-Added Videos
    func loadLocalMedia() {
        // 1. Bundled media (packaged with app)
        let bundled: [Media] = [
            Media(type: .video, fileName: "chilis.mp4"),
            Media(type: .video, fileName: "koreanburger.mp4"),
            Media(type: .image, fileName: "burger.jpg")
        ]
        
        // 2. User-added videos from Documents directory
        let userVideos: [Media] = NewVideoManager.shared.getLocalMedia()
        
        // 3. Combine them (user videos show first)
        mediaItems = userVideos + bundled
        
        collectionView.reloadData()
        
        // Autoplay the first video
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.scrollViewDidEndDecelerating(self.collectionView)
        }
    }

    // MARK: - Collection View DataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return mediaItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = mediaItems[indexPath.row]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MediaCell", for: indexPath) as! MediaCollectionViewCell
        
        if item.type == .image {
            cell.configureImage(fileName: item.fileName)
        } else if item.type == .video {
            cell.configureVideo(fileName: item.fileName)
        }

        return cell
    }

    // MARK: - Collection View Layout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: collectionView.bounds.height)
    }

    // MARK: - Scroll Behavior: Pause All, Play One
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        for cell in collectionView.visibleCells {
            if let videoCell = cell as? MediaCollectionViewCell {
                videoCell.pauseVideo()
            }
        }

        let center = CGPoint(x: collectionView.bounds.midX, y: collectionView.bounds.midY)
        if let indexPath = collectionView.indexPathForItem(at: center),
           let cell = collectionView.cellForItem(at: indexPath) as? MediaCollectionViewCell,
           mediaItems[indexPath.row].type == .video {
            cell.playVideo()
        }
    }

    // MARK: - Pause all videos when leaving
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for cell in collectionView.visibleCells {
            if let videoCell = cell as? MediaCollectionViewCell {
                videoCell.pauseVideo()
            }
        }
    }
}
