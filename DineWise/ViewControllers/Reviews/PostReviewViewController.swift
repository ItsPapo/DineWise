//
//  PostReviewViewController.swift
//  DineWise
//
//  Created by Carlos Castro on 2025-04-02.
//

import UIKit
import AVFoundation
import UniformTypeIdentifiers

class PostReviewViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var videoPreview: UIView!
    var selectedVideoURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    func saveVideoToDocumentsDirectory() -> URL? {
        guard let sourceURL = selectedVideoURL else { return nil }

        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = UUID().uuidString + ".mp4"
        let destURL = documentsDir.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destURL)
            print("✅ Video saved to: \(destURL)")
            return destURL
        } catch {
            print("❌ Error copying video: \(error)")
            return nil
        }
    }
    @IBAction func submitReviewTapped(_ sender: UIButton) {
        guard let savedURL = saveVideoToDocumentsDirectory() else { return }

        // Store this URL in a shared model or pass it to Explore page
        NewVideoManager.shared.addVideo(url: savedURL)

        // Dismiss or pop the review page
        navigationController?.popViewController(animated: true)
    }

    // 🔘 Connect this to your "Add Video" button
    @IBAction func addVideoTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Attach Video", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Record Video", style: .default, handler: { _ in
            self.openCamera()
        }))
        
        alert.addAction(UIAlertAction(title: "Choose from Library", style: .default, handler: { _ in
            self.openLibrary()
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }

    // MARK: - Open Camera
    func openCamera() {
    #if targetEnvironment(simulator)
        // We're in the simulator – no camera available
        let alert = UIAlertController(title: "Camera Not Available",
                                      message: "Recording video is only available on a real device.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    #else
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            let alert = UIAlertController(title: "Camera Not Available",
                                          message: "Your device does not support video recording.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.movie.identifier]
        picker.cameraCaptureMode = .video
        picker.videoQuality = .typeMedium
        present(picker, animated: true)
    #endif
    }



    // MARK: - Open Photo Library
    func openLibrary() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.mediaTypes = [UTType.movie.identifier] // ✅ updated
        picker.videoQuality = .typeMedium
        present(picker, animated: true)
    }

    // MARK: - Picker Result
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let mediaURL = info[.mediaURL] as? URL {
            selectedVideoURL = mediaURL
            print("🎥 Selected video: \(mediaURL.lastPathComponent)")

            // ✅ Save the video
            if let savedURL = saveVideoToDocumentsDirectory(from: mediaURL) {
                // ✅ Add to shared manager
                NewVideoManager.shared.addVideo(url: savedURL)
                print("✅ Video added to Explore: \(savedURL.lastPathComponent)")
            }

            previewVideo(url: mediaURL) // optional preview
        }

        picker.dismiss(animated: true)
    }
    func saveVideoToDocumentsDirectory(from sourceURL: URL) -> URL? {
        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = UUID().uuidString + ".mov"
        let destURL = documentsDir.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destURL)
            return destURL
        } catch {
            print("❌ Failed to save video: \(error)")
            return nil
        }
    }



    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    // MARK: - Preview Video
    func previewVideo(url: URL) {
        let player = AVPlayer(url: url)
        let layer = AVPlayerLayer(player: player)
        layer.frame = videoPreview.bounds
        layer.videoGravity = .resizeAspectFill

        // Clear previous layers
        videoPreview.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        videoPreview.layer.addSublayer(layer)
        player.play()
    }
}
