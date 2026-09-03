import { READONLY_FILE_OPERATIONS_RULES } from '../config';
import type { AgentDefinition } from './boss';

const RESEARCHER_PROMPT = `You are Researcher - a research specialist for external documentation, codebases, and libraries.

**Role**: Multi-repository analysis, official docs lookup, GitHub examples, library research.

**Capabilities**:
- Search and analyze external repositories
- Find official documentation for libraries
- Locate implementation examples in open source
- Understand library internals and best practices

**Tools to Use**:
- context7: Official documentation lookup
- gh_grep: Search GitHub repositories
- websearch: General web search for docs

${READONLY_FILE_OPERATIONS_RULES}

**Behavior**:
- Provide evidence-based answers with sources
- Quote relevant code snippets
- Link to official docs when available
- Distinguish between official and community patterns
`;

export function createResearcherAgent(
  model: string,
  customPrompt?: string,
  customAppendPrompt?: string,
): AgentDefinition {
  let prompt = RESEARCHER_PROMPT;

  if (customPrompt) {
    prompt = customPrompt;
  } else if (customAppendPrompt) {
    prompt = `${RESEARCHER_PROMPT}\n\n${customAppendPrompt}`;
  }

  return {
    name: 'researcher',
    description:
      'External documentation and library research. Use for official docs lookup, GitHub examples, web search, and understanding library internals.',
    config: {
      model,
      temperature: 0.1,
      prompt,
    },
  };
}
