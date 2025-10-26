//
//  Untitled.swift
//  DineWise
//
//  Created by Carlos Castro on 2025-04-02.
//

class VideoReview {
    var fileName: String
    var comment: String?

    init(fileName: String, comment: String? = nil) {
        self.fileName = fileName
        self.comment = comment
    }
}
