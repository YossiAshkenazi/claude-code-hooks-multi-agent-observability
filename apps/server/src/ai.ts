import Anthropic from '@anthropic-ai/sdk';
import OpenAI from 'openai';

// Initialize AI clients
let anthropicClient: Anthropic | null = null;
let openaiClient: OpenAI | null = null;

if (process.env.ANTHROPIC_API_KEY) {
  anthropicClient = new Anthropic({
    apiKey: process.env.ANTHROPIC_API_KEY
  });
}

if (process.env.OPENAI_API_KEY) {
  openaiClient = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY
  });
}

export interface SummarizeRequest {
  event_type: string;
  payload: any;
}

export interface CompletionRequest {
  engineer_name?: string;
}

/**
 * Generate a concise summary of an event for engineers
 */
export async function generateEventSummary(request: SummarizeRequest): Promise<string | null> {
  const { event_type, payload } = request;
  
  // Convert payload to string representation
  let payloadStr = JSON.stringify(payload, null, 2);
  if (payloadStr.length > 1000) {
    payloadStr = payloadStr.substring(0, 1000) + '...';
  }
  
  const prompt = `Generate a one-sentence summary of this Claude Code hook event payload for an engineer monitoring the system.

Event Type: ${event_type}
Payload:
${payloadStr}

Requirements:
- ONE sentence only (no period at the end)
- Focus on the key action or information in the payload
- Be specific and technical
- Keep under 15 words
- Use present tense
- No quotes or formatting
- Return ONLY the summary text

Examples:
- Reads configuration file from project root
- Executes npm install to update dependencies
- Searches web for React documentation
- Edits database schema to add user table
- Agent responds with implementation plan

Generate the summary based on the payload:`;

  try {
    // Try Anthropic first
    if (anthropicClient) {
      const response = await anthropicClient.messages.create({
        model: 'claude-3-5-haiku-20241022',
        max_tokens: 100,
        temperature: 0.7,
        messages: [{ role: 'user', content: prompt }]
      });
      
      const content = response.content[0];
      const text = content && content.type === 'text' ? content.text : null;
      if (text) {
        return text.trim().replace(/^["']|["']$/g, '').replace(/\.$/, '').split('\n')[0]?.trim() || null;
      }
    }
    
    // Fall back to OpenAI
    if (openaiClient) {
      const response = await openaiClient.chat.completions.create({
        model: 'gpt-3.5-turbo',
        max_tokens: 100,
        temperature: 0.7,
        messages: [{ role: 'user', content: prompt }]
      });
      
      const message = response.choices[0]?.message;
      if (message && message.content) {
        return message.content.trim().replace(/^["']|["']$/g, '').replace(/\.$/, '').split('\n')[0]?.trim() || null;
      }
    }
    
    return null;
  } catch (error) {
    console.error('Error generating summary:', error);
    return null;
  }
}

/**
 * Generate a completion message for when Claude finishes a task
 */
export async function generateCompletionMessage(request: CompletionRequest): Promise<string | null> {
  const engineerName = request.engineer_name || process.env.ENGINEER_NAME || '';
  
  let nameInstruction = '';
  let examples = '';
  
  if (engineerName) {
    nameInstruction = `Sometimes (about 30% of the time) include the engineer's name '${engineerName}' in a natural way.`;
    examples = `Examples of the style: 
- Standard: "Work complete!", "All done!", "Task finished!", "Ready for your next move!"
- Personalized: "${engineerName}, all set!", "Ready for you, ${engineerName}!", "Complete, ${engineerName}!", "${engineerName}, we're done!"`;
  } else {
    examples = `Examples of the style: "Work complete!", "All done!", "Task finished!", "Ready for your next move!"`;
  }
  
  const prompt = `Generate a short, concise, friendly completion message for when an AI coding assistant finishes a task. 

Requirements:
- Keep it under 10 words
- Make it positive and future focused
- Use natural, conversational language
- Focus on completion/readiness
- Do NOT include quotes, formatting, or explanations
- Return ONLY the completion message text
${nameInstruction}

${examples}

Generate ONE completion message:`;

  try {
    // Try Anthropic first
    if (anthropicClient) {
      const response = await anthropicClient.messages.create({
        model: 'claude-3-5-haiku-20241022',
        max_tokens: 50,
        temperature: 0.9,
        messages: [{ role: 'user', content: prompt }]
      });
      
      const content = response.content[0];
      const text = content && content.type === 'text' ? content.text : null;
      if (text) {
        const lines = text.trim().replace(/^["']|["']$/g, '').split('\n');
        return lines[0]?.trim() || null;
      }
    }
    
    // Fall back to OpenAI
    if (openaiClient) {
      const response = await openaiClient.chat.completions.create({
        model: 'gpt-3.5-turbo',
        max_tokens: 50,
        temperature: 0.9,
        messages: [{ role: 'user', content: prompt }]
      });
      
      const text = response.choices[0]?.message?.content || null;
      if (text) {
        const lines = text.trim().replace(/^["']|["']$/g, '').split('\n');
        return lines[0]?.trim() || null;
      }
    }
    
    // Fallback to random messages if no AI available
    const fallbackMessages = [
      'Work complete!',
      'All done!',
      'Task finished!',
      'Ready for next task!',
      'Job complete!'
    ];
    
    if (engineerName && Math.random() < 0.3) {
      const personalizedMessages = [
        `${engineerName}, all set!`,
        `Ready for you, ${engineerName}!`,
        `Complete, ${engineerName}!`,
        `${engineerName}, we're done!`
      ];
      const msg = personalizedMessages[Math.floor(Math.random() * personalizedMessages.length)];
      return msg ?? null;
    }
    
    return fallbackMessages[Math.floor(Math.random() * fallbackMessages.length)] || null;
  } catch (error) {
    console.error('Error generating completion message:', error);
    
    // Return fallback message on error
    const fallbackMessages = ['Work complete!', 'All done!', 'Task finished!'];
    return fallbackMessages[Math.floor(Math.random() * fallbackMessages.length)] || null;
  }
}