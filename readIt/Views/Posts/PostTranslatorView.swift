//
//  PostDictionaryView.swift
//  readIt
//
//  Created by 진웅홍 on 7/17/24.
//

import SwiftUI

struct PostTranslatorView: View {
    var selectedBody: String
    @State private var definition: String = ""
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
            } else {
                Text("Selected Text: \(selectedBody)")
                Text("Definition: \(definition)")
                    .padding()
            }
        }
        .navigationTitle("번역 결과")
        .onAppear {
            fetchDefinition(for: selectedBody)
        }
    }

    private func fetchDefinition(for term: String) {
        let service = UrbanDictionaryService()
        service.fetchDefinition(for: term) { result in
            switch result {
            case .success(let response):
                if let firstDefinition = response.definitions.first {
                    self.definition = firstDefinition.definition
                    self.errorMessage = nil
                } else {
                    self.definition = "No definition found."
                }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.definition = ""
            }
        }
    }
}
