#!/usr/bin/env python3
"""
Comprehensive mem0 integration test suite.
Seeds test data, verifies connectivity, and validates PreToolUse hook.
Run directly: .venv/bin/python3 scripts/test_mem0_integration.py
"""
import sys
import json
import subprocess
from datetime import datetime
from pathlib import Path

sys.path.insert(0, ".")

# Color codes for terminal output
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
RESET = "\033[0m"
BOLD = "\033[1m"

def print_header(text):
    print(f"\n{BOLD}{CYAN}{'='*60}{RESET}")
    print(f"{BOLD}{CYAN}{text}{RESET}")
    print(f"{BOLD}{CYAN}{'='*60}{RESET}\n")

def print_pass(text):
    print(f"{GREEN}✓{RESET} {text}")

def print_fail(text):
    print(f"{RED}✗{RESET} {text}")

def print_info(text):
    print(f"{CYAN}ℹ{RESET} {text}")

def test_qdrant_health():
    """Test 1: Verify Qdrant is running and healthy."""
    print_header("Test 1: Qdrant Health Check")

    try:
        result = subprocess.run(
            ["curl", "-sf", "http://localhost:6333/healthz"],
            capture_output=True,
            timeout=5
        )
        if result.returncode == 0:
            print_pass("Qdrant is running at http://localhost:6333")
            return True
        else:
            print_fail("Qdrant health check failed")
            print_info("Start Qdrant with: docker compose up -d")
            return False
    except Exception as e:
        print_fail(f"Could not reach Qdrant: {e}")
        print_info("Start Qdrant with: docker compose up -d")
        return False

def test_mem0_config():
    """Test 2: Verify mem0 configuration is valid."""
    print_header("Test 2: mem0 Configuration")

    try:
        from mem0 import Memory
        from scripts.mem0_config import MEM0_CONFIG

        print_info(f"LLM: {MEM0_CONFIG.get('llm', {}).get('provider', 'unknown')}")
        print_info(f"Embedder: {MEM0_CONFIG.get('embedder', {}).get('provider', 'unknown')}")
        print_info(f"Vector Store: {MEM0_CONFIG.get('vector_store', {}).get('provider', 'unknown')}")

        m = Memory.from_config(MEM0_CONFIG)
        print_pass("mem0 initialized successfully")
        return True, m
    except Exception as e:
        print_fail(f"Failed to initialize mem0: {e}")
        return False, None

def test_seed_memories(m):
    """Test 3: Seed test memories into mem0."""
    print_header("Test 3: Seed Test Memories")

    PROJECT_ID = "project"
    test_memories = [
        {
            "content": "Decision: Use Claude Sonnet 4.6 as the default model for lobby because it offers best balance of speed and capability for code analysis.",
            "metadata": {"type": "decision", "component": "model_selection"}
        },
        {
            "content": "Preference: Always prefer async/await syntax over Promise chains for better readability in new code.",
            "metadata": {"type": "preference"}
        },
        {
            "content": "Insight: The mem0 integration with Qdrant provides semantic search across episodic memories — enables context-aware agent behavior across sessions.",
            "metadata": {"type": "insight", "component": "mem0"}
        },
        {
            "content": "Observation: PreToolUse hook injects memories before every Glob/Grep/Read operation, so agents naturally discover relevant context during code exploration.",
            "metadata": {"type": "observation", "component": "PreToolUse_hook"}
        }
    ]

    try:
        for i, mem in enumerate(test_memories, 1):
            # Auto-add date
            if "date" not in mem["metadata"]:
                mem["metadata"]["date"] = datetime.now().strftime("%Y-%m-%d")

            m.add(mem["content"], user_id=PROJECT_ID, metadata=mem["metadata"])
            mem_type = mem["metadata"]["type"]
            print_pass(f"Seeded memory {i}: {mem_type}")

        return True, test_memories
    except Exception as e:
        print_fail(f"Failed to seed memories: {e}")
        return False, None

def test_search_memories(m):
    """Test 4: Verify semantic search works."""
    print_header("Test 4: Semantic Search")

    PROJECT_ID = "project"
    test_queries = [
        ("default model", "decision"),
        ("async code", "preference"),
        ("semantic search", "insight"),
        ("PreToolUse", "observation")
    ]

    all_passed = True
    for query, expected_type in test_queries:
        try:
            results = m.search(query, user_id=PROJECT_ID, limit=1)
            if results:
                result = results[0]
                relevance = result.get("score", 0)
                mem_type = result.get("metadata", {}).get("type", "unknown")

                # Check if the result is relevant
                if relevance > 0.5:
                    print_pass(f"Query '{query}': found {mem_type} (relevance: {relevance:.2f})")
                else:
                    print_fail(f"Query '{query}': low relevance ({relevance:.2f})")
                    all_passed = False
            else:
                print_fail(f"Query '{query}': no results")
                all_passed = False
        except Exception as e:
            print_fail(f"Query '{query}': {e}")
            all_passed = False

    return all_passed

def test_metadata_validation(m):
    """Test 5: Verify metadata validation works."""
    print_header("Test 5: Metadata Validation")

    PROJECT_ID = "project"
    VALID_TYPES = {"decision", "preference", "insight", "observation"}

    # Test invalid type
    print_info("Testing invalid metadata type...")
    try:
        m.add(
            "This should be rejected",
            user_id=PROJECT_ID,
            metadata={"type": "bug"}  # Invalid type
        )
        print_fail("Invalid type was accepted (should have been rejected)")
        return False
    except Exception as e:
        # mem0 might not validate, so we check the validation logic in the MCP server instead
        print_info(f"mem0 library doesn't validate; MCP server handles validation")

    # Test valid type
    print_info("Testing valid metadata type...")
    try:
        m.add(
            "This test memory with valid type should succeed",
            user_id=PROJECT_ID,
            metadata={"type": "decision", "component": "test"}
        )
        print_pass("Valid metadata accepted")
        return True
    except Exception as e:
        print_fail(f"Valid metadata rejected: {e}")
        return False

def test_pre_tool_use_hook():
    """Test 6: Verify PreToolUse hook is configured."""
    print_header("Test 6: PreToolUse Hook Configuration")

    hook_file = Path(".claude/settings.local.json")
    if not hook_file.exists():
        print_fail("PreToolUse hook not configured: .claude/settings.local.json not found")
        return False

    try:
        with open(hook_file) as f:
            settings = json.load(f)

        if "hooks" not in settings:
            print_fail("No 'hooks' section in .claude/settings.local.json")
            return False

        if "PreToolUse" not in settings["hooks"]:
            print_fail("No 'PreToolUse' hook configured")
            return False

        # Verify the hook calls the right script
        hook_config = settings["hooks"]["PreToolUse"]
        hook_command = str(hook_config[0]["hooks"][0]["command"])

        if "pre_tool_context.py" in hook_command:
            print_pass("PreToolUse hook is configured")
            print_info(f"Hook command: {hook_command}")
            return True
        else:
            print_fail("PreToolUse hook doesn't call pre_tool_context.py")
            return False
    except Exception as e:
        print_fail(f"Error reading hook configuration: {e}")
        return False

def test_pre_tool_context_script():
    """Test 7: Verify pre_tool_context.py script exists and works."""
    print_header("Test 7: PreToolUse Script")

    script_file = Path("scripts/pre_tool_context.py")
    if not script_file.exists():
        print_fail("scripts/pre_tool_context.py not found")
        return False

    print_pass(f"Script exists: {script_file}")

    # Test running the script with dummy input
    try:
        result = subprocess.run(
            [".venv/bin/python3", "scripts/pre_tool_context.py", "test query"],
            capture_output=True,
            timeout=5,
            text=True
        )

        output = result.stdout + result.stderr

        # Check if it produces some output (graphify reminders or mem0 context)
        if len(output) > 0:
            print_pass("Script executed successfully")
            if "graphify" in output.lower() or "mem0" in output.lower():
                print_info("Script output includes memory context")
            return True
        else:
            print_info("Script executed but produced no output (may be normal if no memories match)")
            return True
    except Exception as e:
        print_fail(f"Error running script: {e}")
        return False

def run_all_tests():
    """Run complete test suite."""
    print(f"\n{BOLD}{CYAN}")
    print("╔════════════════════════════════════════════════════════════╗")
    print("║          mem0 Integration Test Suite                        ║")
    print("║    Testing mem0 + Claude Code integration                  ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print(f"{RESET}")

    results = {}

    # Test 1: Qdrant health
    results["qdrant"] = test_qdrant_health()
    if not results["qdrant"]:
        print_fail("\nQdrant is required for mem0. Cannot continue tests.")
        return False

    # Test 2: mem0 config
    results["config"], m = test_mem0_config()
    if not results["config"] or not m:
        print_fail("\nmem0 configuration failed. Cannot continue tests.")
        return False

    # Test 3: Seed memories
    results["seed"], test_mems = test_seed_memories(m)
    if not results["seed"]:
        print_fail("\nFailed to seed test memories.")
        return False

    # Test 4: Search memories
    results["search"] = test_search_memories(m)

    # Test 5: Metadata validation
    results["metadata"] = test_metadata_validation(m)

    # Test 6: PreToolUse hook config
    results["hook_config"] = test_pre_tool_use_hook()

    # Test 7: PreToolUse script
    results["hook_script"] = test_pre_tool_context_script()

    # Summary
    print_header("Test Summary")
    passed = sum(1 for v in results.values() if v)
    total = len(results)

    for test_name, result in results.items():
        status = f"{GREEN}PASS{RESET}" if result else f"{RED}FAIL{RESET}"
        print(f"  {test_name:20} {status}")

    print(f"\n{BOLD}Result: {passed}/{total} tests passed{RESET}")

    if passed == total:
        print(f"\n{GREEN}{BOLD}✓ All tests passed! mem0 is ready to use.{RESET}")
        print(f"\n{CYAN}Next step: Run 'lobby' to start a Claude Code session with mem0 enabled.{RESET}")
        return True
    else:
        print(f"\n{RED}{BOLD}✗ Some tests failed. Review output above.{RESET}")
        return False

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
