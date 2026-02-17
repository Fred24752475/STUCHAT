const OpenAI = require('openai');

// Initialize OpenAI client
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// System prompts for different AI modes
const SYSTEM_PROMPTS = {
  general: `You are a helpful AI assistant for college students. You help with:
- Study tips and techniques
- Homework and assignment help
- Exam preparation strategies
- Course recommendations
- Time management
- Academic writing
- Research assistance

Be friendly, encouraging, and provide practical advice. Keep responses concise but helpful.`,

  tutor: `You are an expert tutor helping college students learn. When explaining concepts:
- Break down complex topics into simple steps
- Use examples and analogies
- Ask questions to check understanding
- Provide practice problems when relevant
- Be patient and encouraging

Focus on teaching, not just giving answers.`,

  homework: `You are a homework helper for college students. When helping with homework:
- Guide students to the solution rather than giving direct answers
- Explain the reasoning and methodology
- Show step-by-step problem solving
- Encourage critical thinking
- Provide similar practice problems

Help them learn, don't just solve it for them.`,

  flashcards: `You are a flashcard generator. Create effective study flashcards:
- Front: Clear, concise question or term
- Back: Accurate, memorable answer or definition
- Use simple language
- Include mnemonics when helpful
- Focus on key concepts

Format as JSON array: [{"front": "question", "back": "answer"}]`,

  summarize: `You are a text summarizer for students. When summarizing:
- Extract key points and main ideas
- Use bullet points for clarity
- Maintain accuracy
- Keep it concise but comprehensive
- Highlight important terms

Make it easy to review and study from.`,

  essay: `You are an academic writing assistant. Help students with:
- Essay structure and organization
- Thesis statements
- Argument development
- Citations and references
- Grammar and style
- Proofreading

Provide constructive feedback and suggestions for improvement.`,
};

class OpenAIService {
  /**
   * Send a chat message to OpenAI
   */
  static async chat(messages, mode = 'general', options = {}) {
    try {
      const systemPrompt = SYSTEM_PROMPTS[mode] || SYSTEM_PROMPTS.general;
      
      const completion = await openai.chat.completions.create({
        model: options.model || 'gpt-4o-mini', // Fast and cost-effective
        messages: [
          { role: 'system', content: systemPrompt },
          ...messages,
        ],
        temperature: options.temperature || 0.7,
        max_tokens: options.maxTokens || 1000,
        stream: options.stream || false,
      });

      return {
        success: true,
        message: completion.choices[0].message.content,
        usage: completion.usage,
      };
    } catch (error) {
      console.error('OpenAI API Error:', error);
      
      // Handle specific error types
      if (error.status === 429) {
        if (error.code === 'insufficient_quota') {
          return {
            success: false,
            error: 'OpenAI API quota exceeded. Please check your billing details at https://platform.openai.com/account/billing',
            errorType: 'quota_exceeded',
          };
        }
        return {
          success: false,
          error: 'Rate limit exceeded. Please try again in a moment.',
          errorType: 'rate_limit',
        };
      }
      
      if (error.status === 401) {
        return {
          success: false,
          error: 'Invalid API key. Please check your OpenAI configuration.',
          errorType: 'auth_error',
        };
      }
      
      return {
        success: false,
        error: error.message || 'Failed to communicate with AI service',
        errorType: 'unknown',
      };
    }
  }

  /**
   * Generate flashcards from text
   */
  static async generateFlashcards(text, count = 10) {
    try {
      const prompt = `Generate ${count} flashcards from this text:\n\n${text}\n\nReturn as JSON array with format: [{"front": "question", "back": "answer"}]`;
      
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: SYSTEM_PROMPTS.flashcards },
          { role: 'user', content: prompt },
        ],
        temperature: 0.7,
        response_format: { type: 'json_object' },
      });

      const response = JSON.parse(completion.choices[0].message.content);
      return {
        success: true,
        flashcards: response.flashcards || response,
      };
    } catch (error) {
      console.error('Flashcard Generation Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Summarize text
   */
  static async summarize(text, length = 'medium') {
    try {
      const lengthGuide = {
        short: '3-5 bullet points',
        medium: '5-8 bullet points',
        long: 'detailed summary with 10-15 bullet points',
      };

      const prompt = `Summarize this text in ${lengthGuide[length]}:\n\n${text}`;
      
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: SYSTEM_PROMPTS.summarize },
          { role: 'user', content: prompt },
        ],
        temperature: 0.5,
      });

      return {
        success: true,
        summary: completion.choices[0].message.content,
      };
    } catch (error) {
      console.error('Summarization Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Solve homework problem
   */
  static async solveHomework(problem, subject) {
    try {
      const prompt = `Subject: ${subject}\n\nProblem: ${problem}\n\nProvide a step-by-step solution with explanations.`;
      
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: SYSTEM_PROMPTS.homework },
          { role: 'user', content: prompt },
        ],
        temperature: 0.3, // Lower temperature for more accurate solutions
      });

      return {
        success: true,
        solution: completion.choices[0].message.content,
      };
    } catch (error) {
      console.error('Homework Solver Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Help with essay writing
   */
  static async helpWithEssay(essayText, helpType = 'feedback') {
    try {
      let prompt;
      switch (helpType) {
        case 'feedback':
          prompt = `Provide constructive feedback on this essay:\n\n${essayText}`;
          break;
        case 'improve':
          prompt = `Suggest improvements for this essay:\n\n${essayText}`;
          break;
        case 'grammar':
          prompt = `Check grammar and style in this essay:\n\n${essayText}`;
          break;
        default:
          prompt = `Help with this essay:\n\n${essayText}`;
      }
      
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: SYSTEM_PROMPTS.essay },
          { role: 'user', content: prompt },
        ],
        temperature: 0.7,
      });

      return {
        success: true,
        feedback: completion.choices[0].message.content,
      };
    } catch (error) {
      console.error('Essay Helper Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Generate practice questions
   */
  static async generateQuestions(topic, count = 5, difficulty = 'medium') {
    try {
      const prompt = `Generate ${count} ${difficulty} difficulty practice questions about: ${topic}\n\nInclude answers and explanations.`;
      
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: SYSTEM_PROMPTS.tutor },
          { role: 'user', content: prompt },
        ],
        temperature: 0.8,
      });

      return {
        success: true,
        questions: completion.choices[0].message.content,
      };
    } catch (error) {
      console.error('Question Generation Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Explain a concept
   */
  static async explainConcept(concept, level = 'college') {
    try {
      const prompt = `Explain "${concept}" at a ${level} level. Use examples and analogies to make it clear.`;
      
      const completion = await openai.chat.completions.create({
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: SYSTEM_PROMPTS.tutor },
          { role: 'user', content: prompt },
        ],
        temperature: 0.7,
      });

      return {
        success: true,
        explanation: completion.choices[0].message.content,
      };
    } catch (error) {
      console.error('Concept Explanation Error:', error);
      return this._handleError(error);
    }
  }

  /**
   * Centralized error handler for OpenAI API errors
   */
  static _handleError(error) {
    if (error.status === 429) {
      if (error.code === 'insufficient_quota') {
        return {
          success: false,
          error: 'OpenAI API quota exceeded. Please check your billing details at https://platform.openai.com/account/billing',
          errorType: 'quota_exceeded',
        };
      }
      return {
        success: false,
        error: 'Rate limit exceeded. Please try again in a moment.',
        errorType: 'rate_limit',
      };
    }
    
    if (error.status === 401) {
      return {
        success: false,
        error: 'Invalid API key. Please check your OpenAI configuration.',
        errorType: 'auth_error',
      };
    }
    
    return {
      success: false,
      error: error.message || 'Failed to communicate with AI service',
      errorType: 'unknown',
    };
  }
}

module.exports = OpenAIService;
