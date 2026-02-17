const { GoogleGenerativeAI } = require('@google/generative-ai');

// Initialize Gemini client
let genAI;
try {
  genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
} catch (error) {
  console.error('Failed to initialize Gemini:', error.message);
}

// System prompts for different AI modes - Enhanced with educational focus
const SYSTEM_PROMPTS = {
  general: `You are an enthusiastic learning companion for college students! 🎓 You help with:
- Study strategies and time management tips
- Assignment guidance and homework support  
- Exam preparation and study techniques
- Course planning and resource recommendations
- Academic writing and research skills
- Motivation and confidence building

Your goal is to make learning feel exciting and achievable! Be friendly, encouraging, and break complex topics into simple, manageable steps. Celebrate small wins and keep students motivated to learn! 💪`,

  tutor: `You are an inspiring tutor who makes learning feel like an adventure! 🚀 Your approach:
- Turn complex topics into interesting, relatable examples
- Use analogies and real-world connections to make concepts click
- Ask engaging questions to spark curiosity and check understanding
- Provide practice problems that build confidence step by step
- Be patient and celebrate every moment of understanding

Focus on creating "aha!" moments where students feel smart and capable. Your enthusiasm should be contagious! ✨`,

  homework: `You are a supportive homework coach who helps students master challenges! 🏆 When helping with homework:
- Guide students through the solution like a friendly mentor
- Explain the "why" behind each step to build deep understanding
- Show problem-solving strategies that students can use again
- Encourage students to try parts on their own to build confidence
- Celebrate their progress and learning journey

Your goal is to help students feel proud of their work and excited to tackle the next challenge! Focus on understanding, not just speed. 💪`,

  essay: `You are an encouraging writing coach who makes academic writing feel empowering! ✍️ When helping with writing:
- Transform complex essay structures into clear, manageable steps
- Help students find their voice and express ideas confidently
- Make thesis statements feel exciting and achievable
- Provide constructive feedback that builds skills, not just corrects errors
- Share techniques for overcoming writer's block and anxiety

Your goal is to help students become confident, powerful communicators who enjoy expressing their ideas! 📚`,

  scan: `You are an AI learning assistant with amazing problem-solving skills! 🔍 When students share homework problems:
- Excitedly analyze what type of problem they're working on
- Break down complex problems into clear, logical steps
- Explain the concepts behind each step to build real understanding
- Offer multiple solution approaches when possible
- Create similar practice problems that reinforce learning
- Celebrate their effort and encourage them to try similar problems

Your goal is to help students feel like problem-solving champions who can tackle any challenge! Make learning feel like solving fun puzzles! 🧩`,

  schedule: `You are an academic success coach who makes studying feel organized and motivating! 📅 When creating study schedules:
- Design realistic schedules that students can actually follow and feel good about
- Balance study time with breaks and social time for well-being
- Suggest creative study techniques for different learning styles
- Help students set achievable goals that build momentum
- Include reward systems and celebration points for sticking to schedules
- Adapt plans based on their energy levels and other commitments

Your goal is to help students feel in control of their learning journey and excited about their progress! Make productivity feel rewarding! ⭐`,

  quiz: `You are a fun quiz master who makes learning feel like an exciting game! 🎯 When creating practice questions:
- Design questions that feel like interesting challenges, not stressful tests
- Include a mix of question types to engage different learning styles
- Provide encouraging hints and explanations for wrong answers
- Build from easy to moderately difficult to create confidence
- Include fun facts or real-world connections in questions
- Celebrate correct answers enthusiastically and explain concepts clearly

Your goal is to help students learn through play and discovery, making knowledge acquisition feel natural and enjoyable! 🎮`,
};

class GeminiService {
  /**
   * Send a chat message to Gemini
   */
  static async chat(messages, mode = 'general', options = {}) {
    try {
      if (!genAI) {
        throw new Error('Gemini API not initialized. Please check your API key.');
      }

      const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });
      const systemPrompt = SYSTEM_PROMPTS[mode] || SYSTEM_PROMPTS.general;

      // Convert messages to Gemini format
      const chatHistory = messages.slice(0, -1).map(msg => ({
        role: msg.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: msg.content }],
      }));

      const chat = model.startChat({
        history: chatHistory,
        generationConfig: {
          temperature: options.temperature || 0.7,
          maxOutputTokens: options.maxTokens || 1000,
        },
      });

      // Add system prompt to the user message
      const lastMessage = messages[messages.length - 1];
      const prompt = `${systemPrompt}\n\nUser: ${lastMessage.content}`;

      const result = await chat.sendMessage(prompt);
      const response = await result.response;

      return {
        success: true,
        message: response.text(),
      };
    } catch (error) {
      console.error('Gemini Chat Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Generate flashcards from text
   */
  static async generateFlashcards(text, count = 10) {
    try {
      if (!genAI) {
        throw new Error('Gemini API not initialized. Please check your API key.');
      }

      const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });
      const prompt = `Generate ${count} flashcards from this text. Return ONLY a JSON array with format: [{"front": "question", "back": "answer"}]

Text:
${text}`;

      const result = await model.generateContent(prompt);
      const response = await result.response;
      const responseText = response.text();

      // Extract JSON from response
      const jsonMatch = responseText.match(/\[[\s\S]*\]/);
      if (jsonMatch) {
        const flashcards = JSON.parse(jsonMatch[0]);
        return {
          success: true,
          flashcards: flashcards,
        };
      }

      throw new Error('Failed to parse flashcards response');
    } catch (error) {
      console.error('Flashcard Generation Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Extract hashtags from text
   */
  static extractHashtags(text) {
    const hashtagRegex = /#[\w]+/g;
    const matches = text.match(hashtagRegex);
    return matches ? matches.map(match => match.toLowerCase()) : [];
  }

  /**
   * Handle API errors
   */
  static _handleError(error) {
    if (!error) {
      return {
        success: false,
        error: 'Unknown error occurred',
        errorType: 'unknown',
      };
    }

    const errorMessage = error.message || error.toString();

    // Check for quota exceeded errors
    if (errorMessage.includes('quota') || errorMessage.includes('billing') || errorMessage.includes('exceeded')) {
      return {
        success: false,
        error: 'API quota exceeded. Please check your billing settings.',
        errorType: 'quota_exceeded',
      };
    }

    // Check for rate limit errors
    if (errorMessage.includes('rate limit') || errorMessage.includes('too many requests')) {
      return {
        success: false,
        error: 'Rate limit exceeded. Please wait a moment and try again.',
        errorType: 'rate_limit',
      };
    }

    return {
      success: false,
      error: errorMessage || 'Failed to communicate with AI service',
      errorType: 'unknown',
    };
  }

  /**
   * Summarize text
   */
  static async summarize(text, length = 'medium') {
    try {
      if (!genAI) {
        throw new Error('Gemini API not initialized. Please check your API key.');
      }

      const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });
      const lengthGuide = {
        short: '3-5 bullet points',
        medium: '5-8 bullet points',
        long: 'detailed summary with 10-15 bullet points',
      };

      const prompt = `Summarize this text in ${lengthGuide[length]}:

${text}`;

      const result = await model.generateContent(prompt);
      const response = await result.response;

      return {
        success: true,
        summary: response.text(),
      };
    } catch (error) {
      console.error('Summarization Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Solve homework
   */
  static async solveHomework(problem, subject = 'General') {
    try {
      if (!genAI) {
        throw new Error('Gemini API not initialized. Please check your API key.');
      }

      const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });
      const prompt = `You are a homework helper. When helping with this homework:
- Guide students to the solution rather than giving direct answers
- Explain the reasoning and methodology
- Show step-by-step problem solving
- Encourage critical thinking
- Provide similar practice problems

Problem: ${problem}
Subject: ${subject}`;

      const result = await model.generateContent(prompt);
      const response = await result.response;

      return {
        success: true,
        solution: response.text(),
      };
    } catch (error) {
      console.error('Homework Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Essay help
   */
  static async helpWithEssay(text, helpType = 'feedback') {
    try {
      if (!genAI) {
        throw new Error('Gemini API not initialized. Please check your API key.');
      }

      const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });
      const prompt = `You are an academic writing assistant. Help students with:
- Essay structure and organization
- Thesis statements
- Argument development
- Citations and references
- Grammar and style
- Proofreading

Text: ${text}

Help Type: ${helpType}`;

      const result = await model.generateContent(prompt);
      const response = await result.response;

      return {
        success: true,
        feedback: response.text(),
      };
    } catch (error) {
      console.error('Essay Help Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Generate practice questions
   */
  static async generateQuestions(topic, count = 5, difficulty = 'medium') {
    try {
      if (!genAI) {
        throw new Error('Gemini API not initialized. Please check your API key.');
      }

      const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });
      const prompt = `Generate ${count} practice questions for "${topic}" at ${difficulty} difficulty level. Include a mix of question types:
1. Multiple choice questions with 4 options
2. Short answer questions for detailed understanding
3. Problem-solving questions that apply concepts
4. True/false questions for quick concept checks

Provide answer keys and explanations for all questions.`;

      const result = await model.generateContent(prompt);
      const response = await result.response;

      return {
        success: true,
        questions: response.text(),
      };
    } catch (error) {
      console.error('Questions Generation Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Explain concept
   */
  static async explainConcept(concept, level = 'college') {
    try {
      if (!genAI) {
        throw new Error('Gemini API not initialized. Please check your API key.');
      }

      const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });
      const prompt = `Explain the concept "${concept}" at ${level} level. Use examples and analogies to make it easy to understand.`;

      const result = await model.generateContent(prompt);
      const response = await result.response;

      return {
        success: true,
        explanation: response.text(),
      };
    } catch (error) {
      console.error('Concept Explanation Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Enhanced homework problem solving for AI Study Buddy Pro
   */
  static async solveHomeworkPro(problemText, mode = 'scan', conversationHistory = []) {
    try {
      if (!genAI) {
        throw new Error('Gemini API not initialized. Please check your API key.');
      }

      const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });
      const systemPrompt = SYSTEM_PROMPTS[mode] || SYSTEM_PROMPTS.scan;

      // Build conversation context from history
      const contextMessages = conversationHistory.slice(0, -1).map(msg => ({
        role: msg.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: msg.content }],
      }));

      const chat = model.startChat({
        history: contextMessages,
        generationConfig: {
          temperature: 0.3,
          maxOutputTokens: 2000,
        },
      });

      // Add enhanced system prompt to user message
      const prompt = `${systemPrompt}\n\nHomework Problem:\n${problemText}`;

      const result = await chat.sendMessage(prompt);
      const response = await result.response;

      return {
        success: true,
        message: response.text(),
      };
    } catch (error) {
      console.error('Enhanced Homework Solving Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Generate personalized study schedule
   */
  static async generateStudySchedule(preferences, recentActivity) {
    try {
      if (!genAI) {
        throw new Error('Gemini API not initialized. Please check your API key.');
      }

      const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });

      const prompt = `You are an expert academic scheduler. Create a personalized study schedule based on:

User Preferences: ${JSON.stringify(preferences)}
Recent Activity: ${JSON.stringify(recentActivity)}

Generate a comprehensive study schedule that includes:
1. **Daily Schedule**: Time blocks for different subjects
2. **Weekly Overview**: Subject distribution across the week
3. **Study Techniques**: Recommended methods for each subject type
4. **Break Times**: Scheduled breaks for optimal learning
5. **Goals**: Weekly learning objectives
6. **Progress Tracking**: How to monitor improvement

Format the response in markdown with clear sections and actionable advice.`;

      const result = await model.generateContent(prompt);
      const response = await result.response;

      return {
        success: true,
        schedule: response.text(),
      };
    } catch (error) {
      console.error('Study Schedule Generation Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Generate adaptive practice quiz
   */
  static async generatePracticeQuiz(topic, difficulty, questionCount, avgScore) {
    try {
      if (!genAI) {
        throw new Error('Gemini API not initialized. Please check your API key.');
      }

      const model = genAI.getGenerativeModel({ model: 'gemini-flash-latest' });

      const prompt = `You are an expert quiz creator. Generate a practice quiz with these specifications:

Topic: ${topic}
Difficulty: ${difficulty}
Number of Questions: ${questionCount}
Student's Average Score: ${avgScore}%

Based on average score, adjust difficulty appropriately:
- If avgScore > 85%, increase difficulty slightly
- If avgScore < 60%, decrease difficulty slightly
- If avgScore is 60-85%, maintain specified difficulty

Generate a quiz with:
1. **Multiple Choice Questions**: 4 options each
2. **Short Answer Questions**: Test deeper understanding
3. **Problem-Solving Questions**: Apply concepts to solve problems
4. **True/False Questions**: Quick concept checks

Format as JSON:
{
  "title": "Quiz Title",
  "questions": [
    {
      "type": "multiple_choice",
      "question": "Question text",
      "options": ["A", "B", "C", "D"],
      "correct_answer": "A",
      "explanation": "Why this is correct"
    }
  ],
  "estimated_time": "15-20 minutes",
  "passing_score": 70
}`;

      const result = await model.generateContent(prompt);
      const response = await result.response;
      const responseText = response.text();

      // Extract JSON from response
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const quiz = JSON.parse(jsonMatch[0]);
        return {
          success: true,
          quiz: quiz,
        };
      }

      // Fallback if JSON parsing fails
      return {
        success: true,
        quiz: {
          title: `${topic} Quiz`,
          questions: [],
          estimated_time: "15-20 minutes",
          passing_score: 70,
          raw_response: responseText
        }
      };
    } catch (error) {
      console.error('Quiz Generation Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Analyze educational video content
   */
  static async analyzeVideo(videoPath, options = {}) {
    try {
      if (!genAI) {
        throw new Error('Gemini API not initialized. Please check your API key.');
      }

      const model = genAI.getGenerativeModel({ model: 'gemini-pro-vision' });

      const analysisPrompt = options.extractConcepts ? `
        Analyze this educational video and provide detailed analysis. Include:
        
        📚 **Educational Content Analysis**:
        - Main topics and concepts covered
        - Learning objectives and key takeaways
        - Difficulty level (beginner, intermediate, advanced)
        - Teaching methods used
        
        🎯 **Content Quality Assessment**:
        - Clarity and explanation quality
        - Engagement and presentation style
        - Accuracy of information
        - Visual aids and demonstrations
        
        📝 **Suggested Improvements**:
        - Ways to make content more engaging
        - Additional topics to cover
        - Better examples or analogies
        - Interactive elements to add
        
        🏷️ **Target Audience**:
        - Appropriate grade/education level
        - Prerequisites assumed
        - Learning outcomes expected
        
        📊 **SEO & Discoverability**:
        - Relevant hashtags for discoverability
        - Keywords for search optimization
        - Thumbnail suggestions
        - Title recommendations
        
        Return as JSON with sections: content_analysis, quality_assessment, suggestions, metadata
      ` : `Analyze this educational video for learning value, key concepts, and engagement factors.`;

      const result = await model.generateContent(analysisPrompt);
      const response = await result.response;

      let analysis = null;
      try {
        // Try to extract JSON from response
        const jsonMatch = response.text().match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          analysis = JSON.parse(jsonMatch[0]);
        } else {
          // Fallback to structured analysis
          analysis = {
            content_analysis: response.text(),
            suggestions: {
              hashtags: this.extractHashtags(response.text()),
              improvements: ["Add visual examples", "Speak more slowly", "Include summary"]
            }
          };
        }
      } catch (parseError) {
        // If JSON parsing fails, use raw response
        analysis = {
          content_analysis: response.text(),
          suggestions: {
            hashtags: this.extractHashtags(response.text()),
            improvements: []
          }
        };
      }

      return {
        success: true,
        analysis
      };
    } catch (error) {
      console.error('Video Analysis Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Extract hashtags from text
   */
  static extractHashtags(text) {
    const hashtagRegex = /#[\w]+/g;
    const matches = text.match(hashtagRegex);
    return matches ? matches.map(match => match.toLowerCase()) : [];
  }

  /**
   * Handle API errors
   */
  static _handleError(error) {
    if (!error) {
      return {
        success: false,
        error: 'Unknown error occurred',
        errorType: 'unknown',
      };
    }

    const errorMessage = error.message || error.toString();

    // Check for quota exceeded errors
    if (errorMessage.includes('quota') || errorMessage.includes('billing') || errorMessage.includes('exceeded')) {
      return {
        success: false,
        error: 'API quota exceeded. Please check your billing settings.',
        errorType: 'quota_exceeded',
      };
    }

    // Check for rate limit errors
    if (errorMessage.includes('rate limit') || errorMessage.includes('too many requests')) {
      return {
        success: false,
        error: 'Rate limit exceeded. Please wait a moment and try again.',
        errorType: 'rate_limit',
      };
    }

    return {
      success: false,
      error: errorMessage || 'Failed to communicate with AI service',
      errorType: 'unknown',
    };
  }
}

module.exports = GeminiService;