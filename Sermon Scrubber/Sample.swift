//
//  Sample.swift
//  Sermon Scrubber
//
//  Created by Steven Hovater on 4/7/25.
//

import Foundation
extension ScrubDocument {
    /// Creates a sample document with test data for previews
    static func sampleScrub() -> ScrubDocument {
        var sample = ScrubDocument()
        
        // Set document metadata
        sample.documentTitle = "Sample Sermon"
        sample.sermonTitle = "Finding Peace in Troubled Times"
        sample.preacher = "Pastor John Smith"
        sample.location = "First Community Church"
        sample.preachDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        
        // Set transcription
        let transcription = """
        Good morning everyone. Today I want to talk about finding peace in troubled times. You know, we live in a world full of challenges and uncertainties. In John 14:27, Jesus tells us, "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid."
        
        So what does this mean for us today? I think there are three key points we can take from this passage.
        
        First, peace is a gift. It's not something we manufacture on our own. Jesus says "I give you." It's freely offered to us.
        
        Second, this peace is different from what the world offers. The world's peace is often temporary and conditional. It depends on circumstances. But the peace Jesus gives transcends our circumstances.
        
        Third, this peace is an antidote to fear and trouble. "Do not let your hearts be troubled and do not be afraid." When we have this divine peace, we can face life's challenges with confidence.
        
        Let me share a story about this. Last year, I met a woman named Sarah who was diagnosed with a serious illness...
        """
        
        sample.originalTranscription = transcription
        sample.setTranscription(transcription)
        
        // Add cleaned up version
        sample.addVersion(title: "Cleaned Version", content: """
        # Finding Peace in Troubled Times
        
        We live in a world full of challenges and uncertainties. In John 14:27, Jesus tells us, "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid."
        
        ## What This Means For Us
        
        There are three key points we can take from this passage:
        
        1. **Peace is a gift.** It's not something we manufacture on our own. Jesus says "I give you." It's freely offered to us.
        
        2. **This peace is different from what the world offers.** The world's peace is often temporary and conditional. It depends on circumstances. But the peace Jesus gives transcends our circumstances.
        
        3. **This peace is an antidote to fear and trouble.** "Do not let your hearts be troubled and do not be afraid." When we have this divine peace, we can face life's challenges with confidence.
        """, type: .cleanedUp)
        
        // Add blog post version
        sample.addVersion(title: "Blog Post", content: """
        # Finding Peace in a Chaotic World
        
        In today's fast-paced, constantly connected world, peace can seem more elusive than ever. News cycles bombard us with crises, social media keeps us in a state of comparison and anxiety, and personal challenges can leave us feeling overwhelmed.
        
        But what if there's a peace available to us that doesn't depend on our circumstances?
        
        ## The Promise of a Different Kind of Peace
        
        In one of the most comforting passages in scripture, Jesus offers these words: "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid." (John 14:27)
        
        This isn't just a nice sentiment—it's a profound promise that can transform how we navigate life's challenges. Let's break down what makes this peace so different:
        
        ### 1. It's a Gift, Not an Achievement
        
        Notice Jesus doesn't say "Peace I will help you find" or "Peace you can earn if you try hard enough." He says "I give you." We don't have to qualify for it, earn it, or somehow become worthy of it. It's freely offered.
        
        Many of us exhaust ourselves trying to create perfect circumstances that we think will bring us peace. But Jesus offers it directly, no prerequisites required.
        
        ### 2. It's Unlike the World's Peace
        
        The peace the world offers is fickle because it's based on external factors:
        - Financial security
        - Perfect relationships
        - Absence of conflict
        - Everything going according to plan
        
        The problem? These conditions rarely align, and when they temporarily do, they never last.
        
        Jesus offers something fundamentally different—a peace that remains steady regardless of what's happening around us. It's an internal state that external circumstances can't touch.
        
        ### 3. It Directly Addresses Our Fears
        
        "Do not let your hearts be troubled and do not be afraid."
        
        This divine peace serves as a counterweight to the anxiety and fear that so often characterize our lives. It doesn't necessarily remove our problems, but it changes how we experience them.
        """, type: .blogPost)
        
        // Add devotional version
        sample.addVersion(title: "Devotional", content: """
        # Daily Devotional: The Gift of Peace
        
        **Scripture Reading:** John 14:27
        
        > "Peace I leave with you; my peace I give you. I do not give to you as the world gives. Do not let your hearts be troubled and do not be afraid."
        
        ## Reflection
        
        When Jesus spoke these words, he was preparing his disciples for his departure. He knew they would face persecution, hardship, and uncertainty. Yet in that moment, he offered them something precious—his peace.
        
        This wasn't a peace dependent on ideal circumstances. It wasn't the kind of temporary calm that comes when everything is going well. This was a peace that could sustain them through the darkest times.
        
        The same peace is offered to us today. No matter what storms we face—whether personal struggles, relational conflict, health concerns, or financial pressures—we can experience a transcendent peace that defies logical explanation.
        
        ## Today's Challenge
        
        Identify one situation in your life that threatens your sense of peace. It might be a relationship, a health concern, a work problem, or something else entirely.
        
        Instead of focusing on how to fix or escape the situation, practice receiving the peace of Christ in the midst of it. Close your eyes, take a deep breath, and visualize yourself accepting peace as a gift directly from Jesus.
        
        ## Prayer
        
        *Lord Jesus, thank you for the gift of your peace. I confess that I often look for peace in the wrong places—in perfect circumstances, in control, or in the approval of others. Today I open my hands to receive the unique peace that only you can give. Please quiet my troubled heart and help me to live in your peace, even when my surroundings are chaotic. Amen.*
        """, type: .devotional)
        
        return sample
    }
}
