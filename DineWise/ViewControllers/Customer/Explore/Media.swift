//
//  Media.swift
//  DineWise
//
//  Created by Muhammad Mahad on 2025-03-24.
//

import Foundation

enum MediaType {
    case image
    case video
}

class Media {
    let type: MediaType
    let fileName: String

    init(type: MediaType, fileName: String) {
        self.type = type
        self.fileName = fileName
    }
}

