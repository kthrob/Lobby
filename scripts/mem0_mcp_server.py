"""
MCP stdio server exposing mem0 memory operations to Claude Code.
Tools: add_memory, search_memory, get_all_memories, delete_memory
"""
import sys, json
from mem0 import Memory
sys.path.insert(0, ".")
from scripts.mem0_config import MEM0_CONFIG

m = Memory.from_config(MEM0_CONFIG)
PROJECT_ID = "project"


def handle(request: dict) -> dict:
    method = request.get("method")
    params = request.get("params", {})
    req_id = request.get("id")

    if method == "initialize":
        return {
            "jsonrpc": "2.0", "id": req_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "mem0", "version": "1.0.0"}
            }
        }

    if method == "tools/list":
        return {
            "jsonrpc": "2.0", "id": req_id,
            "result": {"tools": [
                {
                    "name": "add_memory",
                    "description": "Store a memory about this project, a decision, or a developer preference. Persists across Claude Code sessions.",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "content": {"type": "string", "description": "The memory text to store"},
                            "metadata": {"type": "object", "description": "Optional metadata dict (e.g. {type: 'decision', component: 'auth'})"}
                        },
                        "required": ["content"]
                    }
                },
                {
                    "name": "search_memory",
                    "description": "Search stored memories semantically. Use before answering architecture or design questions.",
                    "inputSchema": {
                        "type": "object",
                        "properties": {
                            "query": {"type": "string"},
                            "limit": {"type": "integer", "default": 5}
                        },
                        "required": ["query"]
                    }
                },
                {
                    "name": "get_all_memories",
                    "description": "Retrieve all stored memories for this project.",
                    "inputSchema": {"type": "object", "properties": {}}
                },
                {
                    "name": "delete_memory",
                    "description": "Delete a memory by its ID.",
                    "inputSchema": {
                        "type": "object",
                        "properties": {"memory_id": {"type": "string"}},
                        "required": ["memory_id"]
                    }
                }
            ]}
        }

    if method == "tools/call":
        name = params.get("name")
        args = params.get("arguments", {})

        try:
            if name == "add_memory":
                m.add(
                    args["content"],
                    user_id=PROJECT_ID,
                    metadata=args.get("metadata", {})
                )
                text = f"Stored memory: {args['content'][:80]}..."
            elif name == "search_memory":
                memories = m.search(args["query"], user_id=PROJECT_ID, limit=args.get("limit", 5))
                if not memories:
                    text = "No relevant memories found."
                else:
                    lines = [f"- [{r['id'][:8]}] {r['memory']}" for r in memories]
                    text = "Relevant memories:\n" + "\n".join(lines)
            elif name == "get_all_memories":
                all_mem = m.get_all(user_id=PROJECT_ID)
                if not all_mem:
                    text = "No memories stored yet."
                else:
                    lines = [f"- [{r['id'][:8]}] {r['memory']}" for r in all_mem]
                    text = "\n".join(lines)
            elif name == "delete_memory":
                m.delete(args["memory_id"])
                text = f"Deleted memory {args['memory_id']}"
            else:
                text = f"Unknown tool: {name}"
        except Exception as e:
            text = f"Error: {e}"

        return {
            "jsonrpc": "2.0", "id": req_id,
            "result": {"content": [{"type": "text", "text": text}]}
        }

    return {"jsonrpc": "2.0", "id": req_id, "result": {}}


if __name__ == "__main__":
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            resp = handle(req)
            print(json.dumps(resp), flush=True)
        except Exception as e:
            print(json.dumps({"jsonrpc": "2.0", "error": str(e)}), flush=True)
