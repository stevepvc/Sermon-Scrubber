//
//  AIService+ChatGPT.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/10/25.
//

import Foundation

extension AIManager {
    func callChatGPTAPI(text: String, prompt: String) async throws -> String {
        guard !apiKeyOpenAI.isEmpty else {
            throw NSError(domain: "AI Error", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not configured"])
        }
        
        // Create the request URL
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKeyOpenAI)", forHTTPHeaderField: "Authorization")
        
        let modelName = "gpt-4o"

        // Define system instructions for sermon processing
        let systemContent = """
        You are an expert in communication, rhetoric, and homiletics. You can take the raw transcription of a sermon, and understand it as a record of a form of oral communication. You can take such a transcription and clean it up, so that it becomes a piece of written communication. You can take out artifacts like vocalized pauses, or needless repetition. You can take sentence fragments and revise or complete them so that they make more intelligible written communication. You can tell when a word clearly doesn't fit the context and must have been a transcription error.
        
        An important thing to keep in mind for sermons is that they often contain quotations. It's going to be important to not alter those, especially if they are quotations of scripture. You're aware of the various translations of the Christian scriptures, and make sure you retain the precise wording of any quotations that are there. Other types of quotations should be preserved as well, whenever possible.
        
        A user may want you to take a raw transcription of sermon and give it a first pass, scrubbing it up to produce a clean manuscript of the sermon. Or, the user may want you to help create other forms of the sermon, like transform it into a long blog post or an essay. They may want to transform it into a chapter for a book, create a lesson plan from the material in it, or they may want to separate out different key events into multiple blog posts, or bits of prose for social media. They may want a short list of the pities, most quotable sections.
        Unless providing a list of some sort, or analysis, you don't need to introduce the new versions you're creating with prose. You may give them a title like "Transcription" but then just give the new version without any commentary.

        Alternatively, they may ask for suggestions on what could make the sermon more effective.
        """
        
        // Prepare the message payload
        let payload: [String: Any] = [
            "model": modelName,
            "max_tokens": 4000,
            "messages": [
                [
                    "role": "system",
                    "content": systemContent
                ],
                [
                    "role": "user",
                    "content": "\(prompt)\n\n\(text)"
                ]
            ]
        ]
        
        // Serialize to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        request.httpBody = jsonData
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check for HTTP errors
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AI Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AI Error", code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "API error: \(errorText)"])
        }
        
        // Parse the response
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            if let usage = json["usage"] as? [String: Any] {
                let promptTokens = usage.integerValue(forKey: "prompt_tokens") ?? 0
                let completionTokens = usage.integerValue(forKey: "completion_tokens") ?? 0

                AIUsageTracker.shared.recordUsage(
                    provider: .openAI,
                    model: modelName,
                    inputTokens: promptTokens,
                    outputTokens: completionTokens,
                    metadata: [
                        "endpoint": "chat.completions",
                        "prompt_character_count": "\(text.count)",
                        "prompt_identifier": String(prompt.prefix(32))
                    ]
                )
            }
            return content
        } else {
            // Try to extract error message if possible
            let errorText = String(data: data, encoding: .utf8) ?? "Could not parse response"
            throw NSError(domain: "AI Error", code: 0,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to parse response: \(errorText)"])
        }
    }
}
