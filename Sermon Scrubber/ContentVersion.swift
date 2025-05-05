//
//  ContentVersion.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import Foundation

struct ContentVersion: Identifiable, Codable {
    var id = UUID()
    var title: String
    var content: String
    var dateCreated: Date
    var versionType: VersionType
    var caches: Bool = false  // Default to false for existing types
    
    enum VersionType: String, Codable, CaseIterable {
        case transcript = "Transcript"
        case cleanedUp = "Cleaned Up and Condensed"  // Updated name
        case cleanedUpUnabridged = "Cleaned Up (Unabridged)"  // New type
        case withHeadings = "With Headings"
        case blogPost = "Blog Post"
        case blogPostSeries = "Blog Post Series"
        case bookChapter = "Book Chapter"
        case devotional = "Devotional"
        case summary = "Summary"
        case classLessonPlan = "Class Lesson Plan"
        case growthPoints = "Growth Points"
        case custom = "Custom"
        
        var defaultTitle: String {
            switch self {
            case .transcript: return "Original Transcript"
            case .cleanedUp: return "Cleaned Version (Condensed)"  // Updated
            case .cleanedUpUnabridged: return "Cleaned Version (Unabridged)"  // New
            case .withHeadings: return "Version with Headings"
            case .blogPost: return "Blog Post"
            case .blogPostSeries: return "Blog Post Series"
            case .bookChapter: return "Book Chapter"
            case .devotional: return "Devotional"
            case .summary: return "Summary"
            case .classLessonPlan: return "Class Lesson Plan"
            case .growthPoints: return "Growth Points"
            case .custom: return "Custom Version"
            }
        }
        
        var iconName: String {
            switch self {
            case .transcript: return "doc.text"
            case .cleanedUp: return "sparkles"
            case .cleanedUpUnabridged: return "doc.richtext"  // New icon
            case .withHeadings: return "list.bullet"
            case .blogPost: return "newspaper"
            case .blogPostSeries: return "newspaper.fill"
            case .bookChapter: return "book.closed"
            case .devotional: return "book"
            case .summary: return "doc.plaintext"
            case .classLessonPlan: return "student.desk"
            case .growthPoints: return "chart.line.uptrend.xyaxis"
            case .custom: return "pencil"
            }
        }
    }
}
