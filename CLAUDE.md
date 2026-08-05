## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- MANDATORY FIRST STEP: before answering any question about the code, or before making any code change, run `graphify query "<question>"` (or `graphify path`/`graphify explain`) when graphify-out/graph.json exists. Never rely on memory or guesswork about project structure — check the graph first so you don't get lost.
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- The graph auto-updates after every Edit/Write/NotebookEdit via a PostToolUse hook (`graphify update .`, AST-only, no API cost) and after every git commit/checkout via git hooks. Manual `graphify update .` is only needed for non-code changes (docs/papers/images).
