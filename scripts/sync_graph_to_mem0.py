"""
Reads graphify-out/GRAPH_REPORT.md and promotes god nodes and surprising
connections into mem0 as persistent project memories.

Run after every /graphify build, or wire into the git post-commit hook.
"""
import re, sys
from pathlib import Path
from mem0 import Memory
sys.path.insert(0, ".")
from scripts.mem0_config import MEM0_CONFIG

REPORT_PATH = Path("graphify-out/GRAPH_REPORT.md")
PROJECT_ID = "project"

if not REPORT_PATH.exists():
    print("graphify-out/GRAPH_REPORT.md not found. Run /graphify . first.")
    sys.exit(1)

m = Memory.from_config(MEM0_CONFIG)
report = REPORT_PATH.read_text()

stored = 0

# --- God nodes ---
# Matches lines like: **ClassName** — degree: 42
god_node_pattern = re.findall(
    r"\*\*([A-Za-z0-9_:.<>]+)\*\*[^\n]*?degree[:\s]+(\d+)",
    report
)
for node_name, degree in god_node_pattern:
    content = (
        f"Graph god node: '{node_name}' (degree {degree}). "
        f"This is a high-centrality concept in the codebase — most structural "
        f"relationships pass through it. Treat it as an anchor when navigating."
    )
    m.add(content, user_id=PROJECT_ID, metadata={
        "type": "graph_god_node",
        "node": node_name,
        "degree": int(degree),
        "source": "graphify"
    })
    stored += 1

# --- Surprising connections ---
# Matches lines after a "Surprising connections" heading
surprising_section = re.search(
    r"[Ss]urprising connections?[^\n]*\n(.*?)(?=\n##|\Z)",
    report, re.DOTALL
)
if surprising_section:
    items = re.findall(r"[-*]\s+(.+)", surprising_section.group(1))
    for item in items[:8]:
        content = f"Surprising structural connection in codebase: {item.strip()}"
        m.add(content, user_id=PROJECT_ID, metadata={
            "type": "graph_insight",
            "source": "graphify"
        })
        stored += 1

# --- Suggested questions ---
questions_section = re.search(
    r"[Ss]uggested questions?[^\n]*\n(.*?)(?=\n##|\Z)",
    report, re.DOTALL
)
if questions_section:
    questions = re.findall(r"[-*?]\s*(.+\?)", questions_section.group(1))
    for q in questions[:5]:
        content = f"The knowledge graph suggests this question is worth exploring: {q.strip()}"
        m.add(content, user_id=PROJECT_ID, metadata={
            "type": "graph_suggested_question",
            "source": "graphify"
        })
        stored += 1

print(f"Synced {stored} graph insights to mem0.")
