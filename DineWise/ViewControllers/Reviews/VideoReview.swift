//
//  Untitled.swift
//  DineWise
//
//  Created by Carlos Castro on 2025-04-02.
//

// No subclass, plain Swift class
class VideoReview {
    var fileName: String
    var comment: String?

    init(fileName: String, comment: String? = nil) {
        self.fileName = fileName
        self.comment = comment
    }
}
