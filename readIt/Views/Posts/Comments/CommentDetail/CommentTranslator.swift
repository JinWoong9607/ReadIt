//
//  CommentTranslator.swift
//  readIt
//
//  Created by 진웅홍 on 7/16/24.
//

import SwiftUI
import Combine

struct CommentTranslator: View {
    @Binding var selectedComment: String
    @EnvironmentObject var userId : ReadItLoginUtil
    @State private var definition: String = ""
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        VStack {
            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
            } else {
                Text("Selected Text: \(selectedComment)")
                Text("Definition: \(definition)")
                    .padding()
            }
        }
        .navigationTitle("번역 결과")
        .onAppear {
            fetchDefinition(for: selectedComment)
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
                    self.logDefiniton(userId: userId.username, word: term, meaning: firstDefinition.definition)
                } else {
                    self.definition = "No definition found."
                }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.definition = ""
            }
        }
    }
    
    private func logDefiniton(userId: String, word: String, meaning: String) {
        let dictionaryLog = DictionaryLog(userId: userId, word: word, meaning: meaning)
        DictionaryMaker.shared.makelog(dictionaryLog)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    print("Log created successfully.")
                case .failure(let error):
                    print("Error occurred while logging: \(error.localizedDescription)")
                }
            }, receiveValue: { response in
                print("Log response: \(response)")
            })
            .store(in: &cancellables)
    }
}
