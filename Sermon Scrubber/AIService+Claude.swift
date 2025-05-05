//
//  AIService+Claude.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/10/25.
//

import Foundation

extension AIManager {
    func callClaudeAPI(text: String, prompt: String) async throws -> String {
        guard !apiKeyAnthropic.isEmpty else {
            throw NSError(domain: "AI Error", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not configured"])
        }
        
        // Create the request URL
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Set headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKeyAnthropic, forHTTPHeaderField: "x-api-key")
        
        // Define system instructions for sermon processing
        let systemInstructions = """
        You are an expert in communication, rhetoric, and homiletics. You can take the raw transcription of a sermon, and understand it as a record of a form of oral communication. You can take such a transcription and clean it up, so that it becomes a piece of written communication. You can take out artifacts like vocalized pauses, or needless repetition. You can take sentence fragments and revise or complete them so that they make more intelligible written communication. You can tell when a word clearly doesn't fit the context and must have been a transcription error.
        
        An important thing to keep in mind for sermons is that they often contain quotations. It's going to be important to not alter those, especially if they are quotations of scripture. You're aware of the various translations of the Christian scriptures, and make sure you retain the precise wording of any quotations that are there. Other types of quotations should be preserved as well, whenever possible.
        
        A user may want you to take a raw transcription of sermon and give it a first pass, scrubbing it up to produce a clean manuscript of the sermon. Or, the user may want you to help create other forms of the sermon, like transform it into a long blog post or an essay. They may want to transform it into a chapter for a book, create a lesson plan from the material in it, or they may want to separate out different key events into multiple blog posts, or bits of prose for social media. They may want a short list of the pities, most quotable sections.
        Unless providing a list of some sort, or analysis, you don't need to introduce the new versions you're creating with prose. YOu may give them a title like "Transcription" but then just give the new version without any commentary. 

        Alternatively, they may ask for suggestions on what could make the sermon more effective.
        """
        
        // Prepare the message payload
        let payload: [String: Any] = [
            "model": "claude-3-7-sonnet-20250219",
            "max_tokens": 8192,
            "temperature": 0.3,
            "system": systemInstructions,
            "messages": [
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
           let content = json["content"] as? [[String: Any]],
           let firstItem = content.first(where: { ($0["type"] as? String) == "text" }),
           let text = firstItem["text"] as? String {
            return text
        } else {
            // Try to extract error message if possible
            let errorText = String(data: data, encoding: .utf8) ?? "Could not parse response"
            throw NSError(domain: "AI Error", code: 0,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to parse response: \(errorText)"])
        }
    }
    
    func callClaudeAPIWithCaching(text: String, prompt: String) async throws -> String {
        guard !apiKeyAnthropic.isEmpty else {
            throw NSError(domain: "AI Error", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not configured"])
        }
        
        // Update progress
        await MainActor.run {
            self.progressMessage = "Preparing transcript for processing..."
            self.progressPercentage = 0.1
        }
        
        print("Starting prompt caching approach for unabridged cleaning")
        print("Text length: \(text.count) characters")
        
        // Create the base request
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKeyAnthropic, forHTTPHeaderField: "x-api-key")
        
        // Configure request timeout - increase to 120 seconds
        request.timeoutInterval = 120
        
        // System instructions for cleanup
        let systemInstructions = """
        You are an expert in improving sermon transcripts. Your task is to clean up transcription artifacts while preserving all content and meaning. Fix grammar, remove filler words and repetition, and complete sentence fragments. Your edits should make the text more readable without changing the meaning or removing any content.
        
        Important guidelines:
        1. Preserve all scripture quotations exactly
        2. Maintain the full length of the content
        3. Do not summarize or condense
        4. Fix obvious transcription errors
        5. Maintain the speaker's voice and style
        """
        
        // Split the text into smaller chunks - reduced from 5000 to 2500
        let chunks = splitTextIntoChunks(text, maxChunkSize: 2500)
        let totalChunks = chunks.count
        
        print("Split transcript into \(totalChunks) chunks for processing")
        print("Chunk sizes: \(chunks.map { $0.count })")
        
        // Process each chunk individually
        var processedChunks: [String] = []
        
        for (index, chunk) in chunks.enumerated() {
            // Update progress
            await MainActor.run {
                self.progressMessage = "Processing chunk \(index + 1) of \(totalChunks)..."
                self.progressPercentage = 0.1 + 0.8 * (Double(index) / Double(totalChunks))
            }
            
            print("Processing chunk \(index + 1) of \(totalChunks) - \(chunk.count) characters")
            
            let chunkPrompt = """
            Please clean up this portion of a sermon transcript. Fix grammar errors and remove filler words while keeping all content intact. DO NOT condense or summarize:
            
            \(chunk)
            """
            
            // Calculate and log total request size
            let promptSize = chunkPrompt.count
            print("Prompt size for chunk \(index + 1): \(promptSize) characters")
            
            // Prepare the payload for this chunk
            let payload: [String: Any] = [
                "model": "claude-3-7-sonnet-20250219",
                "max_tokens": 4096,
                "temperature": 0.2,
                "system": systemInstructions,
                "messages": [
                    [
                        "role": "user",
                        "content": chunkPrompt
                    ]
                ]
            ]
            
            // Serialize to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.httpBody = jsonData
            
            // Log payload size
            print("Request payload size: \(jsonData.count) bytes")
            
            // Make the request with improved retry logic
            do {
                let (data, response) = try await makeRequestWithRetry(request: request, maxRetries: 3, chunk: index + 1)
                
                // Check for HTTP errors
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("API error for chunk \(index + 1): \(errorText)")
                    throw NSError(domain: "AI Error", code: (response as? HTTPURLResponse)?.statusCode ?? 0,
                                 userInfo: [NSLocalizedDescriptionKey: "API error: \(errorText)"])
                }
                
                // Parse the response
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("Successfully got response for chunk \(index + 1)")
                    
                    if let content = json["content"] as? [[String: Any]],
                       let firstItem = content.first(where: { ($0["type"] as? String) == "text" }),
                       let processedText = firstItem["text"] as? String {
                        processedChunks.append(processedText)
                        print("Successfully processed chunk \(index + 1) - Result: \(processedText.count) characters")
                    } else {
                        // Try to extract error message if possible
                        let errorText = String(data: data, encoding: .utf8) ?? "Could not parse response"
                        print("Failed to parse response for chunk \(index + 1): \(errorText)")
                        print("Response JSON: \(json)")
                        throw NSError(domain: "AI Error", code: 0,
                                     userInfo: [NSLocalizedDescriptionKey: "Failed to parse response: \(errorText)"])
                    }
                } else {
                    // Try to extract error message if possible
                    let errorText = String(data: data, encoding: .utf8) ?? "Could not parse response"
                    print("Failed to parse JSON for chunk \(index + 1): \(errorText)")
                    throw NSError(domain: "AI Error", code: 0,
                                 userInfo: [NSLocalizedDescriptionKey: "Failed to parse response: \(errorText)"])
                }
            } catch {
                print("Failed to process chunk \(index + 1) after retries: \(error.localizedDescription)")
                
                // If this is the first chunk and we can't process it, try with an even smaller chunk
                if index == 0 && chunks.count == 1 {
                    print("Attempting to process with smaller chunk size")
                    
                    // Try with an even smaller chunk size as a fallback
                    return try await processWithSmallerChunks(text: text, prompt: prompt, systemInstructions: systemInstructions)
                } else {
                    throw error
                }
            }
        }
        
        // Update progress for final step
        await MainActor.run {
            self.progressMessage = "Finalizing cleaned transcript..."
            self.progressPercentage = 0.9
        }
        
        print("All chunks processed, combining results")
        
        // Combine all processed chunks
        let combinedResult = processedChunks.joined(separator: "\n\n")
        
        // Final step: Only do a final pass if we had multiple chunks
        if totalChunks > 1 {
            print("Performing final consistency pass on the combined result")
            
            let finalPrompt = """
            Here is a cleaned up sermon transcript that was processed in parts. Please do a light editing pass to ensure consistency throughout and fix any transition issues between sections:
            
            \(combinedResult)
            """
            
            // Prepare the final payload
            let finalPayload: [String: Any] = [
                "model": "claude-3-7-sonnet-20250219",
                "max_tokens": 4096,
                "temperature": 0.2,
                "system": systemInstructions,
                "messages": [
                    [
                        "role": "user",
                        "content": finalPrompt
                    ]
                ]
            ]
            
            // Update the request with the final payload
            let finalJsonData = try JSONSerialization.data(withJSONObject: finalPayload, options: [])
            request.httpBody = finalJsonData
            
            // Make the final request
            let (finalData, finalResponse) = try await makeRequestWithRetry(request: request, maxRetries: 3, chunk: 0)
            
            // Check for HTTP errors
            guard let finalHttpResponse = finalResponse as? HTTPURLResponse, finalHttpResponse.statusCode == 200 else {
                let errorText = String(data: finalData, encoding: .utf8) ?? "Unknown error"
                print("Final processing API error: \(errorText)")
                
                // If the final pass fails, just return the combined result
                print("Final pass failed, returning combined chunks without final processing")
                
                await MainActor.run {
                    self.progressMessage = "Completed with partial processing!"
                    self.progressPercentage = 1.0
                }
                
                return combinedResult
            }
            
            // Parse the final response
            if let json = try JSONSerialization.jsonObject(with: finalData) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let firstItem = content.first(where: { ($0["type"] as? String) == "text" }),
               let finalText = firstItem["text"] as? String {
                
                print("Successfully completed unabridged cleaning with final pass")
                
                // Update progress to complete
                await MainActor.run {
                    self.progressMessage = "Completed!"
                    self.progressPercentage = 1.0
                }
                
                return finalText
            } else {
                // If the final pass parsing fails, just return the combined result
                print("Failed to parse final response, returning combined chunks")
                
                await MainActor.run {
                    self.progressMessage = "Completed with partial processing!"
                    self.progressPercentage = 1.0
                }
                
                return combinedResult
            }
        } else {
            print("Single chunk processed, no need for final pass")
            
            // Update progress to complete
            await MainActor.run {
                self.progressMessage = "Completed!"
                self.progressPercentage = 1.0
            }
            
            return combinedResult
        }
    }
    // Helper function to split text into manageable chunks
    private func splitTextIntoChunks(_ text: String, maxChunkSize: Int) -> [String] {
        if text.count <= maxChunkSize {
            return [text]
        }
        
        var chunks: [String] = []
        let paragraphs = text.components(separatedBy: "\n\n")
        
        var currentChunk = ""
        
        for paragraph in paragraphs {
            // If adding this paragraph would exceed max size, save current chunk and start a new one
            if currentChunk.count + paragraph.count > maxChunkSize && !currentChunk.isEmpty {
                chunks.append(currentChunk)
                currentChunk = paragraph
            } else {
                // Add paragraph to current chunk
                if !currentChunk.isEmpty {
                    currentChunk += "\n\n"
                }
                currentChunk += paragraph
            }
        }
        
        // Add the last chunk if it's not empty
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks
    }
    private func processWithSmallerChunks(text: String, prompt: String, systemInstructions: String) async throws -> String {
        print("Attempting to process with ultra-small chunks")
        
        // Split into much smaller chunks - 1000 characters each
        let smallChunks = splitTextIntoChunks(text, maxChunkSize: 1000)
        print("Split into \(smallChunks.count) ultra-small chunks")
        
        var processedSmallChunks: [String] = []
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKeyAnthropic, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 180  // Even longer timeout for small chunks
        
        for (index, chunk) in smallChunks.enumerated() {
            await MainActor.run {
                self.progressMessage = "Processing micro-chunk \(index + 1) of \(smallChunks.count)..."
                self.progressPercentage = 0.1 + 0.8 * (Double(index) / Double(smallChunks.count))
            }
            
            print("Processing micro-chunk \(index + 1) of \(smallChunks.count) - \(chunk.count) characters")
            
            let chunkPrompt = """
            Please clean up this small portion of a sermon transcript. Fix grammar errors and remove filler words while keeping all content intact:
            
            \(chunk)
            """
            
            // Simple payload for small chunks
            let payload: [String: Any] = [
                "model": "claude-3-7-sonnet-20250219",
                "max_tokens": 2048,
                "temperature": 0.2,
                "system": systemInstructions,
                "messages": [
                    [
                        "role": "user",
                        "content": chunkPrompt
                    ]
                ]
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.httpBody = jsonData
            
            do {
                let (data, response) = try await makeRequestWithRetry(request: request, maxRetries: 3, chunk: index + 1)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    continue  // Skip this chunk if it fails
                }
                
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let firstItem = content.first(where: { ($0["type"] as? String) == "text" }),
                   let processedText = firstItem["text"] as? String {
                    processedSmallChunks.append(processedText)
                    print("Successfully processed micro-chunk \(index + 1)")
                } else {
                    print("Failed to parse response for micro-chunk \(index + 1), skipping")
                }
            } catch {
                print("Failed to process micro-chunk \(index + 1): \(error.localizedDescription), skipping")
                // Just skip failed chunks in this emergency mode
                continue
            }
        }
        
        if processedSmallChunks.isEmpty {
            throw NSError(domain: "AI Error", code: 0,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to process any parts of the text"])
        }
        
        // Return whatever we managed to process
        let result = processedSmallChunks.joined(separator: "\n\n")
        
        await MainActor.run {
            self.progressMessage = "Completed with partial processing!"
            self.progressPercentage = 1.0
        }
        
        return result
    }
    // Helper function to retry requests
    private func makeRequestWithRetry(request: URLRequest, maxRetries: Int, chunk: Int) async throws -> (Data, URLResponse) {
        var retries = 0
        var lastError: Error?
        
        while retries < maxRetries {
            do {
                print("Making request for chunk \(chunk), attempt \(retries + 1) of \(maxRetries)")
                
                // Create a copy of the request with a fresh timeout
                var freshRequest = request
                freshRequest.timeoutInterval = 120 + (30 * Double(retries))  // Increase timeout with each retry
                
                let result = try await URLSession.shared.data(for: freshRequest)
                print("Request for chunk \(chunk) succeeded on attempt \(retries + 1)")
                return result
            } catch {
                lastError = error
                retries += 1
                print("Request failed for chunk \(chunk) (attempt \(retries)/\(maxRetries)): \(error.localizedDescription)")
                
                // Add longer exponential backoff
                if retries < maxRetries {
                    let delay = TimeInterval(pow(2.0, Double(retries))) * 1.0  // Doubled the base delay
                    print("Waiting \(delay) seconds before retrying...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NSError(domain: "AI Error", code: 0,
                                  userInfo: [NSLocalizedDescriptionKey: "Request failed after multiple attempts"])
    }
    
}
