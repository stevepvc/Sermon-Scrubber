//
//  ContentProcessingType.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//
import Foundation

enum ContentProcessingType {
    case cleanup
    case addHeadings
    case blogPost
    case blogPostSeries
    case bookChapter
    case devotional
    case summary
    case classLessonPlan
    case growthPoints
    
    var description: String {
        switch self {
        case .cleanup: return "Clean up text"
        case .addHeadings: return "Add headings"
        case .blogPost: return "Create blog post"
        case .blogPostSeries: return "Create blog post series"
        case .bookChapter: return "Create book chapter"
        case .devotional: return "Create devotional"
        case .summary: return "Create summary"
        case .classLessonPlan: return "Create lesson plan"
        case .growthPoints: return "Identify growth points"
        }
    }
}

// Extension to convert between our types
extension ContentProcessingType {
    static func from(versionType: ContentVersion.VersionType) -> ContentProcessingType? {
        switch versionType {
        case .cleanedUp: return .cleanup
        case .withHeadings: return .addHeadings
        case .blogPost: return .blogPost
        case .blogPostSeries: return .blogPostSeries
        case .bookChapter: return .bookChapter
        case .devotional: return .devotional
        case .summary: return .summary
        case .classLessonPlan: return .classLessonPlan
        case .growthPoints: return .growthPoints
        case .transcript, .custom: return nil
        }
    }
}
