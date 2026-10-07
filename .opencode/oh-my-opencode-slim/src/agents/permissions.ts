type AgentPermission = Record<
  string,
  'allow' | 'ask' | 'deny' | Record<string, 'allow' | 'ask' | 'deny'>
>;

/**
 * Strict read-only tool permissions for advisory agents.
 *
 * Start with wildcard deny so newly-added tools are unavailable by default,
 * then allow only inspection/search tools. Explicitly deny known mutating and
 * delegation tools to make the read-only boundary obvious in generated config.
 */
export function createReadOnlyAgentPermission(): AgentPermission {
  return {
    '*': 'deny',
    bash: 'deny',
    edit: 'deny',
    write: 'deny',
    apply_patch: 'deny',
    ast_grep_replace: 'deny',
    task: 'deny',
    question: 'deny',
    read: 'allow',
    glob: 'allow',
    grep: 'allow',
    lsp: 'allow',
    list: 'allow',
    codesearch: 'allow',
    ast_grep_search: 'allow',
  } as AgentPermission;
}
