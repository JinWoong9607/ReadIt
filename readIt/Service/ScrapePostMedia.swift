//
//  ScrapeComments.swift
//  OpenArtemis
//
//  Created by daniel on 05/12/23.
//

import Foundation
import SwiftSoup
import Defaults

private let invalidURLError = NSError(domain: "Invalid URL", code: 0, userInfo: nil)
private let noDataError = NSError(domain: "No data received", code: 0, userInfo: nil)

extension RedditScraper {
    private static func parseUserTextBody(data: Document) throws -> String? {
        let postBody = try data.select("div.expando").first()
        
        var body: String? = nil
        if let bodyElement = postBody, !(try bodyElement.text().isEmpty) {
            let modifiedHtmlBody = try redditLinksToInternalLinks(bodyElement)
            
            var document = readItHTML(rawHTML: modifiedHtmlBody)
            try document.parse()
            body = try document.asMarkdown()
        }
        
        return body
    }

    static func scrapeComments(commentURL: String, sort: SortOption? = nil,
                               completion: @escaping (Result<(comments: [Comment], postBody: String?), Error>) -> Void) {
        var urlComponents = URLComponents(string: commentURL)
        var queryItems = [URLQueryItem]()

        if let sort = sort {
            queryItems.append(URLQueryItem(name: "sort", value: sort.rawVal.value))
        }

        // Append the existing query items
        if let existingQueryItems = urlComponents?.queryItems {
            queryItems.append(contentsOf: existingQueryItems)
        }

        // Set the updated query items to the URL components
        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }

        let group = DispatchGroup()
        var commentsResult: Result<[Comment], Error>?
        var postBodyResult: Result<String?, Error>?

        group.enter()
        webViewManager.loadURLAndGetHTML(url: url) { result in
            switch result {
            case .success(let htmlContent):
                do {
                    let doc = try SwiftSoup.parse(htmlContent)

                    let comments = try parseCommentsData(data: doc)
                    let postBody = try parseUserTextBody(data: doc)

                    completion(.success((comments: comments, postBody: postBody)))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }

        group.notify(queue: .main) {
            let result: Result<(comments: [Comment], postBody: String?), Error>

            switch (commentsResult, postBodyResult) {
            case let (.success(comments), .success(postBody)):
                result = .success((comments: comments, postBody: postBody))
            case let (.failure(error), _):
                result = .failure(error)
            case let (_, .failure(error)):
                result = .failure(error)
            default:
                fatalError("Invalid state")
            }

            completion(result)
        }

    }
    
    static func parseCommentsData(data: Document) throws -> [Comment] {
        var comments: [Comment] = []
        var commentIDs = Set<String>()
        
        // Elements for reduced calls
        let topLevelComments = try? data.select("div.sitetable.nestedlisting > div.comment")

        // Function to recursively parse comments
        func parseComment(commentElement: Element, parentID: String?, depth: Int) throws {
            let id = try commentElement.attr("data-fullname")
            
            // Check for duplicate comments
            guard commentIDs.insert(id).inserted else {
                return
            }
            
            let author = try commentElement.attr("data-author")
            let scoreText = try commentElement.select("span.score.unvoted").first()?.text() ?? ""
            let score = scoreText.components(separatedBy: " ").first ?? "[score hidden]"
            let time = try commentElement.select("time").first()?.attr("datetime") ?? ""
            
            let bodyElement = try commentElement.select("div.entry.unvoted > form[id^=form-\(id)]").first()

            // Replace links in HTML with internal links, and convert body to markdown
            var body = ""
            if let bodyElement = bodyElement, !author.isEmpty {
                let modifiedHtmlBody = try redditLinksToInternalLinks(bodyElement)
                
                var document = readItHTML(rawHTML: modifiedHtmlBody)
                try document.parse()
                body = try document.asMarkdown()
            }
            
            // check for stickied tag
            let stickiedElement = try commentElement.select("span.stickied-tagline").first()
            let stickied = stickiedElement != nil
            
            let directURL = try commentElement.select("a.bylink").attr("href")

            let comment = Comment(id: id, parentID: parentID, author: author, score: score, time: time, body: body,
                                  depth: depth, stickied: stickied, directURL: directURL, isCollapsed: false, isRootCollapsed: stickied)
            comments.append(comment)
            
            // Check for child comments
            if let childElement = try? commentElement.select("div.child > div.sitetable.listing > div.comment") {
                try childElement.forEach { childCommentElement in
                    try parseComment(commentElement: childCommentElement, parentID: id, depth: depth + 1)
                }
            }
        }
        
        // Parse top-level comments
        if let topLevelComments = topLevelComments {
            comments.reserveCapacity(topLevelComments.size())
            try topLevelComments.forEach { commentElement in
                try parseComment(commentElement: commentElement, parentID: nil, depth: 0)
            }
        }
        
        return comments
    }
    
    static func scrapePostFromURL(url: String, completion: @escaping (Result<Post, Error>) -> Void) {
        print("Attempting to scrape post from URL: \(url)")
        guard let urlObject = URL(string: url) else {
            let error = NSError(domain: "Invalid URL", code: 0, userInfo: nil)
            print("Error: Invalid URL - \(url)")
            completion(.failure(error))
            return
        }
        
        webViewManager.loadURLAndGetHTML(url: urlObject) { result in
            switch result {
            case .success(let htmlContent):
                print("Successfully retrieved HTML content from URL: \(url)")
                do {
                    let post = try parsePostData(html: htmlContent).first
                    if let post = post {
                        print("Successfully parsed post data from HTML content for URL: \(url)")
                        completion(.success(post))
                    } else {
                        let error = NSError(domain: "Post Parsing Error", code: 1, userInfo: [NSLocalizedDescriptionKey: "No post data found in HTML"])
                        print("Error: No post data found in HTML content from URL: \(url)")
                        completion(.failure(error))
                    }
                } catch {
                    print("Error while parsing post data for URL \(url): \(error.localizedDescription)")
                    completion(.failure(error))
                }
            case .failure(let error):
                print("Failed to load HTML from URL: \(url) with error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

func redditLinksToInternalLinks(_ element: Element) throws -> String {
    do {
        let links = try element.select("a[href]")

        for link in links.array() {
            let originalHref = try link.attr("href")
    
            if originalHref.hasPrefix("/r/") || originalHref.hasPrefix("/u/") || originalHref.contains("reddit.com") {
                // Directly convert Reddit specific links
                try link.attr("href", "readIt://\(originalHref)")
            } else if originalHref.hasPrefix("http://") || originalHref.hasPrefix("https://") {
                // Remove scheme for other HTTP/HTTPS links and convert
                if let url = URL(string: originalHref), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                    components.scheme = nil
                    let trimmedHref = components.string?.trimmingCharacters(in: .punctuationCharacters)
                    try link.attr("href", "readIt://\(trimmedHref ?? "")")
                    
                    // Optionally replace the text of the link
                    if !Defaults[.appTheme].showOriginalURL {
                        try link.text(components.host ?? originalHref)
                    }
                }
            } else {
                // Handle any other scheme or malformed URL normally
                try link.attr("href", "readIt://\(originalHref)")
            }
        }
        return try element.html()
    } catch {
        throw error
    }
}

func convertRedditLinkToInternal(_ link: String) -> String {
    if link.hasPrefix("/r/") || link.hasPrefix("/u/") || link.contains("reddit.com") {
        return "readIt://\(link)"
    } else if link.hasPrefix("http://") || link.hasPrefix("https://") {
        if let url = URL(string: link), var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.scheme = nil
            let trimmedLink = components.string?.trimmingCharacters(in: .punctuationCharacters) ?? ""
            return "readIt://\(trimmedLink)"
        }
    }
    return "readIt://\(link)"
}
