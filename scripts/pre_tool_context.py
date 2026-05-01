"""
Injected by the PreToolUse hook before every Glob/Grep/Read tool call.
Emits:
  1. graphify graph reminder (if graph exists)
  2. Top 2 mem0 memories relevant to the tool input
"""
import sys, json
from pathlib import Path
from mem0 import Memory
sys.path.insert(0, ".")
from scripts.mem0_config import MEM0_CONFIG

tool_input_raw = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else ""

# Extract a usable query string from tool input (may be JSON or plain text)
try:
    tool_data = json.loads(tool_input_raw)
    query = (
        tool_data.get("pattern")
        or tool_data.get("path")
        or tool_data.get("query")
        or str(tool_data)
    )[:120]
except (json.JSONDecodeError, TypeError):
    query = tool_input_raw[:120]

# 1. graphify reminder
if Path("graphify-out/graph.json").exists():
    print(
        "graphify: Knowledge graph exists. "
        "Read GRAPH_REPORT.md for god nodes and community structure "
        "before searching raw files. Use query_graph MCP tool for specific lookups."
    )

# 2. mem0 context
if query.strip():
    try:
        m = Memory.from_config(MEM0_CONFIG)
        raw = m.search(query, filters={"user_id": "project"}, limit=2)
        memories = raw.get("results", raw) if isinstance(raw, dict) else raw
        for mem in memories:
            score = mem.get("score", "")
            score_str = f" (relevance: {score:.2f})" if isinstance(score, float) else ""
            print(f"mem0: Past context{score_str} — {mem['memory']}")
    except Exception:
        pass  # Never block tool execution on memory errors
