//
//  NewVideoManager.swift
//  DineWise
//
//  Created by Carlos Castro on 2025-04-02.
//

import Foundation

class NewVideoManager {
    static let shared = NewVideoManager()
    private init() {}

    private var localVideoURLs: [URL] = []

    func addVideo(url: URL) {
        if !localVideoURLs.contains(url) {
            localVideoURLs.insert(url, at: 0)
        }
    }

    func getLocalMedia() -> [Media] {
        return localVideoURLs.map { Media(type: .video, fileName: $0.lastPathComponent) }
    }

    func getStoredVideoURL(for fileName: String) -> URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docs.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
}
