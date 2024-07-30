//
//  ScrapeProfile.swift
//  OpenArtemis
//
//  Created by Ethan Bills on 12/26/23.
//

import SwiftUI
import SwiftSoup

extension RedditScraper {
    static func scrapeProfile(username: String, lastPostAfter: String?, filterType: String?,
                               over18: Bool? = false,
                              completion: @escaping (Result<[MixedMedia], Error>) -> Void) {
        // Construct the base URL for the Reddit user's profile
        var urlString = "\(baseRedditURL)/user/\(username)"

        // Append filter type to the URL if provided
        if let filterType = filterType, !filterType.isEmpty {
            urlString += "/\(filterType)"
        }

        // Append after parameter to the URL if lastPostAfter is provided
        if let lastPostAfter = lastPostAfter, !lastPostAfter.isEmpty {
            urlString += "?after=\(lastPostAfter)"
        }

        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        webViewManager.loadURLAndGetHTML(url: url, autoClickExpando: true) { result in
            switch result {
            case .success(let htmlContent):
                do {

                    let posts = try parsePostData(html: htmlContent)
                        let comments = try parseProfileComments(html: htmlContent)

                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

                        // Combine posts and comments into an array of MixedMedia
                        var mixedMediaLinks: [MixedMedia] = []

                        // Iterate over posts and add to mixedMediaLinks
                        for post in posts {
                            mixedMediaLinks.append(MixedMedia.post(post, date: dateFormatter.date(from: post.time)))
                        }

                        // Iterate over comments and add to mixedMediaLinks
                        for comment in comments {
                            mixedMediaLinks.append(MixedMedia.comment(comment, date: dateFormatter.date(from: comment.time)))
                        }

                        DateSortingUtils.sortMixedMediaByDateDescending(&mixedMediaLinks)

                        completion(.success(mixedMediaLinks))
                    } catch {
                        // Catches error from `parsePostData` or `parseProfileComments`.
                        completion(.failure(error))
                    }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    static func parseProfileComments(html: String) throws -> [Comment] {
        let doc = try SwiftSoup.parse(html)
        let commentElements = try doc.select("div.thing.comment")
        
        let comments = commentElements.compactMap { commentElement -> Comment? in
            do {
                return try parseProfileCommentElement(commentElement: commentElement)
            } catch {
                // Handle any specific errors here if needed
                print("Error parsing comment element: \(error)")
                return nil
            }
        }

        return comments
    }

    private static func parseProfileCommentElement(commentElement: Element) throws -> Comment {
        let id = try commentElement.attr("data-fullname")
        let parentID = try? commentElement.attr("data-parent-fullname")
        let author = try commentElement.attr("data-author")
        let scoreText = try commentElement.select("span.score.unvoted").first()?.text() ?? ""
        let score = scoreText.components(separatedBy: " ").first ?? "[score hidden]"
        let time = try commentElement.select("time").first()?.attr("datetime") ?? ""

        let bodyElement = try commentElement.select("div.entry.unvoted > form[id*=form-\(id)]").first()

        // Replace links in HTML with internal links, and convert body to markdown
        var body = ""
        if let bodyElement = bodyElement {
            let modifiedHtmlBody = try redditLinksToInternalLinks(bodyElement)

            var document = readItHTML(rawHTML: modifiedHtmlBody)
            try document.parse()
            body = try document.asMarkdown()
        }

        // Check for stickied tag
        let stickiedElement = try commentElement.select("span.stickied-tagline").first()
        let stickied = stickiedElement != nil

        let directURL = try commentElement.select("a.bylink").attr("href")
        
        return Comment(id: id, parentID: parentID, author: author, score: score, time: time, body: body,
                       depth: 0, stickied: stickied, directURL: directURL, isCollapsed: false, isRootCollapsed: stickied)
    }
    
    static func scrapeCommentThread(commentURL: String, completion: @escaping (Result<(Post, [Comment]), Error>) -> Void) {
        guard let url = URL(string: commentURL) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        webViewManager.loadURLAndGetHTML(url: url, autoClickExpando: false, preventCacheClear: true) { result in
            switch result {
            case .success(let htmlContent):
                do {
                    let (post, comments) = try parseCommentThread(html: htmlContent)
                    completion(.success((post, comments)))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    static func parseCommentThread(html: String) throws -> (Post, [Comment]) {
        let doc = try SwiftSoup.parse(html)
        
        // Parse the main post
        let postElement = try doc.select("div.link").first()
        guard let postElement = postElement else {
            throw NSError(domain: "Post not found", code: 0, userInfo: nil)
        }
        
        let post = try parsePostElement(postElement)
        
        // Parse the comments
        let commentElements = try doc.select("div.comment")
        let comments = try commentElements.compactMap { try parseCommentElement($0) }
        
        return (post, comments)
    }

    static func parsePostElement(_ element: Element) throws -> Post {
        let id = try element.attr("data-fullname")
        let subreddit = try element.attr("data-subreddit")
        let title = try element.select("p.title a.title").text()
        let tag = try element.select("span.linkflairlabel").first()?.text() ?? ""
        let author = try element.attr("data-author")
        let votes = try element.attr("data-score")
        let time = try element.select("time").attr("datetime")
        let mediaURL = try element.attr("data-url")
        
        let commentsElement = try element.select("a.bylink.comments.may-blank")
        let commentsURL = try commentsElement.attr("href")
        let commentsCount = try commentsElement.text().split(separator: " ").first.map(String.init) ?? ""
        
        let type = PostUtils.shared.determinePostType(mediaURL: mediaURL)
        
        var thumbnailURL: String? = nil
        if type == "video" || type == "gallery" || type == "article", let thumbnailElement = try? element.select("a.thumbnail img").first() {
            thumbnailURL = try? thumbnailElement.attr("src").replacingOccurrences(of: "//", with: "https://")
        }
        
        return Post(id: id, subreddit: subreddit, title: title, tag: tag, author: author, votes: votes, time: time, mediaURL: mediaURL, commentsURL: commentsURL, commentsCount: commentsCount, type: type, thumbnailURL: thumbnailURL)
    }

    static func parseCommentElement(_ element: Element) throws -> Comment {
        let id = try element.attr("data-fullname")
        let parentID = try element.attr("data-parent-id")
        let author = try element.select("a.author").text()
        let score = try element.select("span.score").text()
        let time = try element.select("time").attr("datetime")
        let body = try element.select("div.md").text()
        let depth = try Int(element.attr("data-depth")) ?? 0
        let stickied = try element.classNames().contains("stickied")
        let directURL = try element.select("a.bylink").attr("href")
        
        return Comment(id: id, parentID: parentID, author: author, score: score, time: time, body: body, depth: depth, stickied: stickied, directURL: directURL, isCollapsed: false, isRootCollapsed: false)
    }
}
