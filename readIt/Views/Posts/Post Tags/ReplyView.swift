//
//  ReplyView.swift
//  readIt
//
//  Created by 진웅홍 on 7/25/24.
//

import SwiftUI

struct ReplyView: View {
    let comment: ReadItComment
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(comment.author)
                .font(.headline)
            Text(comment.time)
                .font(.caption)
                .foregroundStyle(Color.secondary)
            Text(comment.body)
                .font(.body)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 10))
    }
}

