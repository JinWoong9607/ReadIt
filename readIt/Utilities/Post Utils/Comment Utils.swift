//
//  Comment Utils.swift
//  OpenArtemis
//
//  Created by Ethan Bills on 12/3/23.
//

import Foundation
import CoreData
import Defaults
import SwiftUI

struct Comment: Equatable, Codable, Hashable {
    let id: String
    let parentID: String?
    let author: String
    let score: String
    let time: String
    let body: String
    let depth: Int
    let stickied: Bool
    let directURL: String
    var isCollapsed: Bool
    var isRootCollapsed: Bool
}

/// Utility class for handling comments.
class CommentUtils {
    /// Shared instance of CommentUtils.
    static let shared = CommentUtils()

    /// Private initializer to enforce singleton pattern.
    private init() {}

    // MARK: - Comment Section Helpers

    /// Preference key to track the anchor points of comments.
    struct AnchorsKey: PreferenceKey {
        typealias Value = [String: Anchor<CGPoint>]
        static var defaultValue: Value { [:] }

        static func reduce(value: inout Value, nextValue: () -> Value) {
            value.merge(nextValue()) { $1 }
        }
    }

    /// Finds the top comment row based on anchors and geometry proxy.
    func topCommentRow(of anchors: CommentUtils.AnchorsKey.Value, in proxy: GeometryProxy) -> String? {
        var yBest = CGFloat.infinity
        var answer: String?
        for (row, anchor) in anchors {
            let y = proxy[anchor].y
            guard y >= 0, y < yBest else { continue }
            answer = row
            yBest = y
        }
        return answer
    }

    // MARK: - Comment Hierarchy and Count

    /// Gets the number of descendants for a given comment.
    func getNumberOfDescendants(for comment: Comment, in comments: [Comment]) -> Int {
        return countDescendants(for: comment, in: comments)
    }

    /// Recursively counts descendants for a given comment.
    func countDescendants(for comment: Comment, in comments: [Comment]) -> Int {
        let children = comments.filter { $0.parentID == comment.id }
        var descendantCount = children.count

        for child in children {
            descendantCount += countDescendants(for: child, in: comments)
        }

        return descendantCount
    }

    // MARK: - Comment Styling

    /// Determines the color for comment indentation based on depth.
    func commentIndentationColor(forDepth depth: Int) -> Color {
        let colorPalette = Defaults[.commentColorPalette]
        let colorIndex = depth % colorPalette.count
        return colorPalette[colorIndex]
    }

    // MARK: - Saved Comment Handling

    /// Converts a `SavedComment` entity to a tuple containing the saved timestamp and the corresponding `Comment`.
    func savedCommentToComment(_ comment: SavedComment) -> (Date?, Comment) {
        return (
            comment.savedTimestamp,
            Comment(
                id: comment.id ?? "",
                parentID: comment.parentID,
                author: comment.author ?? "",
                score: comment.score ?? "",
                time: comment.time ?? "",
                body: comment.body ?? "",
                depth: Int(comment.depth),
                stickied: comment.stickied,
                directURL: comment.directURL ?? "",
                isCollapsed: comment.isCollapsed,
                isRootCollapsed: comment.isRootCollapsed
            )
        )
    }

    /// Toggles the saved status of a `Comment`.
    func toggleSaved(context: NSManagedObjectContext, comment: Comment) {
        if let savedComment = fetchSavedComment(context: context, id: comment.id) {
            removeSavedComment(context: context, savedComment: savedComment)
        } else {
            saveComment(context: context, comment: comment)
        }
    }

    /// Saves a `Comment` entity.
    func saveComment(context: NSManagedObjectContext, comment: Comment) {
        let tempComment = SavedComment(context: context)
        tempComment.id = comment.id
        tempComment.body = comment.body
        tempComment.depth = Int32(comment.depth)
        tempComment.author = comment.author
        tempComment.isCollapsed = comment.isRootCollapsed
        tempComment.isRootCollapsed = comment.isRootCollapsed
        tempComment.parentID = comment.parentID
        tempComment.score = comment.score
        tempComment.stickied = comment.stickied
        tempComment.directURL = comment.directURL
        tempComment.time = comment.time
        tempComment.savedTimestamp = Date()

        DispatchQueue.main.async {
            do {
                try context.save()
            } catch {
                print("Error removing saved post: \(error)")
            }
        }
    }

    /// Removes a saved `Comment` entity.
    func removeSavedComment(context: NSManagedObjectContext, savedComment: SavedComment) {
        context.delete(savedComment)

        DispatchQueue.main.async {
            do {
                try context.save()
            } catch {
                print("Error removing saved post: \(error)")
            }
        }
    }

    /// Fetches all saved comments from the given context.
    func fetchSavedComments(context: NSManagedObjectContext) -> [SavedComment] {
        do {
            return try context.fetch(SavedComment.fetchRequest())
        } catch {
            print("Error fetching saved comments: \(error)")
            return []
        }
    }

    /// Fetches a saved comment by its ID from the given context.
    func fetchSavedComment(context: NSManagedObjectContext, id: String) -> SavedComment? {
        let request: NSFetchRequest<SavedComment> = SavedComment.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)

        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching saved comment: \(error)")
            return nil
        }
    }
    
    func unifyAndSortComments(readItComments: [ReadItComment], comments: [Comment]) -> [UnifiedComment] {
        let unifiedFromReadIt = readItComments.map { UnifiedComment(from: $0) }
        let unifiedFromComments = comments.map { UnifiedComment(from: $0) }
        let combinedComments = unifiedFromReadIt + unifiedFromComments
        return combinedComments.sorted(by: { DateFormatter.commentDateFormatter.date(from: $0.time ) ?? Date() < DateFormatter.commentDateFormatter.date(from: $1.time) ?? Date() })
    }
}

struct UnifiedComment: Equatable, Codable, Hashable {
    let id: String
    let parentID: String?
    let userId: String?
    let author: String
    let score: Int
    let time: String
    let body: String
    let depth: Int
    let stickied: Bool
    let directURL: String
    var isCollapsed: Bool
    var isRootCollapsed: Bool
}

extension UnifiedComment {
    init(from readItComment: ReadItComment) {
        self.id = readItComment.id
        self.parentID = readItComment.parentID
        self.userId = readItComment.userId
        self.author = readItComment.author
        self.score = Int(readItComment.score)
        self.time = readItComment.time
        self.body = readItComment.body
        self.depth = readItComment.depth
        self.stickied = readItComment.stickied
        self.directURL = readItComment.directURL
        self.isCollapsed = readItComment.isCollapsed
        self.isRootCollapsed = readItComment.isRootCollapsed
    }

    init(from comment: Comment) {
        self.id = comment.id
        self.parentID = comment.parentID
        self.userId = nil  // Assuming Comment does not have a userId
        self.author = comment.author
        self.score = Int(comment.score) ?? 0
        self.time = comment.time
        self.body = comment.body
        self.depth = comment.depth
        self.stickied = comment.stickied
        self.directURL = comment.directURL
        self.isCollapsed = comment.isCollapsed
        self.isRootCollapsed = comment.isRootCollapsed
    }
}

extension DateFormatter {
    static let commentDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return formatter
    }()
}

extension CommentUtils {
    func getNumberOfDescendants(for comment: UnifiedComment, in comments: [UnifiedComment]) -> Int {
        let childComments = comments.filter { $0.parentID == comment.id }
        let directDescendants = childComments.count
        let indirectDescendants = childComments.reduce(0) { $0 + getNumberOfDescendants(for: $1, in: comments) }
        return directDescendants + indirectDescendants
    }
}


extension CommentUtils {
    func toggleSaved(context: NSManagedObjectContext, comment: UnifiedComment) {
        // 먼저 이미 저장된 댓글인지 확인합니다.
        let fetchRequest: NSFetchRequest<SavedComment> = SavedComment.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", comment.id)
        
        do {
            let existingComments = try context.fetch(fetchRequest)
            
            if let existingComment = existingComments.first {
                // 이미 저장된 댓글이 있다면 삭제합니다.
                context.delete(existingComment)
                print("댓글 저장 해제: \(comment.id)")
            } else {
                // 저장된 댓글이 없다면 새로 생성하여 저장합니다.
                let savedComment = SavedComment(context: context)
                savedComment.id = comment.id
                savedComment.parentID = comment.parentID
                savedComment.author = comment.author
                savedComment.score = String(comment.score) // score가 String이라고 가정
                savedComment.time = comment.time // Date 타입으로 변환 필요할 수 있음
                savedComment.body = comment.body
                savedComment.depth = Int32(comment.depth)
                savedComment.stickied = comment.stickied
                savedComment.directURL = comment.directURL
                savedComment.isCollapsed = comment.isCollapsed
                savedComment.isRootCollapsed = comment.isRootCollapsed
                
                print("댓글 저장: \(comment.id)")
            }
            
            // 변경사항을 저장합니다.
            try context.save()
        } catch {
            print("댓글 저장/해제 중 오류 발생: \(error)")
        }
    }
}
