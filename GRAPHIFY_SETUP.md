# Graphify + mem0 Integration Setup Guide

This document walks you through integrating graphify (knowledge graphs) and mem0 (persistent memory) into your Claude Code workflow with lobby.

## Prerequisites Check

Before starting, confirm:

- [ ] Python 3.10+ installed: `python3 --version`
- [ ] Ollama running at `http://localhost:11434`: `curl http://localhost:11434/api/tags`
- [ ] Required Ollama models pulled:
  - [ ] `ollama pull llama3`
  - [ ] `ollama pull nomic-embed-text`
- [ ] Docker installed and running (for Qdrant)
- [ ] Claude Code CLI installed: `claude --version`

## Installation Steps

### Step 1: Install graphify

Install graphify using `uv` (recommended) or `pipx`:

```bash
# Using uv (recommended)
uv tool install graphifyy && graphify install

# Or using pipx
pipx install graphifyy && graphify install
```

Install the Claude Code integration:

```bash
graphify claude install
```

This writes a PreToolUse hook to your settings.json (we'll enhance this in Step 7).

### Step 2: Set up Python venv and mem0

From the lobby repo root:

```bash
# Create and activate Python virtual environment
python3 -m venv .venv
source .venv/bin/activate   # On Windows: .venv\Scripts\activate

# Install mem0 and Qdrant client
pip install mem0ai qdrant-client
```

### Step 3: Start Qdrant

From the lobby repo root, start the Qdrant vector store:

```bash
docker compose up -d
```

Verify it's running:

```bash
docker ps | grep qdrant
```

### Step 4: Verify mem0 Configuration

Test that mem0 is configured correctly:

```bash
source .venv/bin/activate
python3 -c "
from mem0 import Memory
import sys
sys.path.insert(0, '.')
from scripts.mem0_config import MEM0_CONFIG

m = Memory.from_config(MEM0_CONFIG)
m.add('Integration test memory', user_id='project')
results = m.search('test', user_id='project', limit=1)
print('✓ mem0 is working!' if results else '✗ mem0 test failed')
"
```

Expected output: `✓ mem0 is working!`

### Step 5: Build Initial Knowledge Graph

From the lobby repo root, inside a Claude Code session, run:

```
/graphify .
```

This builds the initial knowledge graph. Confirm that these files exist:
- `graphify-out/graph.json`
- `graphify-out/GRAPH_REPORT.md`

### Step 6: Install git post-commit hook

Install graphify's git hook (for automatic graph rebuilds):

```bash
graphify hook install
```

Then extend it to sync graph insights to mem0:

```bash
cat >> .git/hooks/post-commit << 'EOF'

# Sync graphify god nodes to mem0 after graph rebuild
if [ -f graphify-out/GRAPH_REPORT.md ]; then
    .venv/bin/python3 scripts/sync_graph_to_mem0.py 2>/dev/null || true
fi
EOF

chmod +x .git/hooks/post-commit
```

### Step 7: Bootstrap mem0 from graph

Sync the initial graph insights into mem0:

```bash
source .venv/bin/activate
.venv/bin/python3 scripts/sync_graph_to_mem0.py
```

Expected output: `Synced N graph insights to mem0.` (N > 0)

### Step 8: Enhance PreToolUse hook

Update your project's `settings.json` to inject contextual memory before every file search. Locate your settings file:

- **Project-specific**: `.claude/settings.json` (in this directory)
- **User-wide**: `~/.claude/settings.json` (in your home directory)

Add or update the `PreToolUse` hook in the `hooks` section:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Glob|Grep|Read",
        "hooks": [
          {
            "type": "command",
            "command": ".venv/bin/python3 scripts/pre_tool_context.py \"$CLAUDE_TOOL_INPUT\""
          }
        ]
      }
    ]
  }
}
```

> If `PreToolUse` already exists (from `graphify claude install`), merge the above into it.

## Verification Checklist

Run each command and confirm the expected output:

```bash
# 1. graphify MCP server responds
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | \
    .venv/bin/python3 -m graphify.serve graphify-out/graph.json
# Expected: JSON listing query_graph, get_node, get_neighbors, shortest_path

# 2. mem0 MCP server responds
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' | \
    .venv/bin/python3 scripts/mem0_mcp_server.py
# Expected: JSON listing add_memory, search_memory, get_all_memories, delete_memory

# 3. God-node sync ran
source .venv/bin/activate
.venv/bin/python3 scripts/sync_graph_to_mem0.py
# Expected: "Synced N graph insights to mem0." (N > 0)

# 4. Memory is retrievable
python3 -c "
from mem0 import Memory
import sys
sys.path.insert(0, '.')
from scripts.mem0_config import MEM0_CONFIG
m = Memory.from_config(MEM0_CONFIG)
r = m.search('god node', user_id='project', limit=3)
print([x['memory'][:60] for x in r])
"
# Expected: list of memory strings about god nodes

# 5. PreToolUse hook fires
.venv/bin/python3 scripts/pre_tool_context.py '{"pattern":"*.py"}'
# Expected: graphify reminder line + mem0 memory lines

# 6. .mcp.json is valid JSON
python3 -c "import json; json.load(open('.mcp.json')); print('valid')"
# Expected: "valid"
```

## Next Steps

1. **Commit graphify outputs**: Add `graphify-out/graph.json` and `graphify-out/GRAPH_REPORT.md` to git.
2. **Start a new Claude Code session**: The `.mcp.json` file will be auto-discovered.
3. **Test the integration**: Try queries that reference architecture — use `query_graph` to navigate the knowledge graph.
4. **Store decisions**: Use `add_memory` to record architectural decisions and preferences.

## Troubleshooting

**Qdrant connection errors:**
```bash
# Check if Qdrant is running
docker ps | grep qdrant

# Restart if needed
docker compose down && docker compose up -d
```

**MCP server not found:**
- Ensure `.mcp.json` exists at the repo root
- Restart Claude Code to re-discover MCP servers
- Check file paths in `.mcp.json` are correct relative to repo root

**Graphify import errors:**
```bash
# Verify graphify is installed
graphify --version

# Reinstall if needed
pipx uninstall graphifyy && pipx install graphifyy
```

**mem0 extraction failures:**
- Ensure Ollama is running: `curl http://localhost:11434/api/tags`
- Check that required models are pulled: `ollama list | grep -E 'llama3|nomic-embed-text'`

## Configuration Reference

- **mem0 LLM model**: Configured in `scripts/mem0_config.py` (default: `llama3`)
- **mem0 embeddings**: Configured in `scripts/mem0_config.py` (default: `nomic-embed-text`)
- **Qdrant host/port**: Configured in `scripts/mem0_config.py` (default: `localhost:6333`)
- **Ollama base URL**: Configured in `scripts/mem0_config.py` (default: `http://localhost:11434`)

To change any of these, edit `scripts/mem0_config.py` and restart Claude Code.
