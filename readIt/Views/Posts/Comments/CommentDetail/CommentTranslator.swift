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
    @State private var showTranslation = false
    @State var translatedText: String = ""
    @State private var translationError: String = ""
    
    var body: some View {
        VStack {
            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
            } else {
                Text("Selected Text: \(selectedComment)")
                Text("Definition: \(definition)")
                    .padding()
                Button("번역하기") {
                    // 먼저 정의를 가져오는 함수를 호출합니다.
                    fetchDefinition(for: selectedComment)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
                
                if showTranslation {
                    ScrollView {
                        VStack(alignment: .leading) {
                            if !translatedText.isEmpty {
                                Text(translatedText)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding()
                            } else if !translationError.isEmpty {
                                Text(translationError)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .foregroundStyle(Color(.red))
                                    .padding()
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .navigationTitle("번역 결과")
    }
    
    private func fetchDefinition(for term: String) {
        let service = UrbanDictionaryService()
        service.fetchDefinition(for: term) { result in
            switch result {
            case .success(let response):
                if let firstDefinition = response.definitions.first {
                    self.definition = firstDefinition.definition
                    self.errorMessage = nil
                    // 정의를 가져온 후, 이 정의를 번역하는 함수를 호출합니다.
                    self.translateComment(comment: firstDefinition.definition)
                } else {
                    self.definition = "No definition found."
                }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.definition = ""
            }
        }
    }
    
    private func translateComment(comment: String) {
        TranslationService.translateComment(comment: comment) { translated, error, show in
            self.translatedText = translated
            self.translationError = error
            self.showTranslation = show
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
