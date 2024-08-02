//
//  Urbandictionary Utils.swift
//  readIt
//
//  Created by 진웅홍 on 7/17/24.
//

import Foundation
import SwiftUI



struct UrbanDictionaryResponse: Codable, Hashable {
    let definitions: [Definition]

    enum CodingKeys: String, CodingKey {
        case definitions = "list"
    }
}

struct Definition: Codable, Hashable, Equatable {
    let definition: String
    let word: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(word)
    }
    
    static func == (lhs: Definition, rhs: Definition) -> Bool {
        return lhs.word == rhs.word
    }

}

class dictionaryUtils {
    static let shared = dictionaryUtils()
    
    private init() {}
    
    
}
