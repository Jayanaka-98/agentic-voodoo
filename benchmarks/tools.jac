"""Real execution tools for skill benchmarks.

These perform actual file I/O and code execution — no mocking.
Output files land in the current working directory (run from repo root).
Each tool captures stdout+stderr and returns it as a string so the LLM
can see real errors, real package output, and real file sizes.
"""

import subprocess;
import tempfile;
import os;
import sys;

# Python interpreter that matches the Jac runtime (has the right packages)
glob _PYTHON: str = sys.executable;
# Node binary from PATH
glob _NODE: str = "node";

# ── File I/O ──────────────────────────────────────────────────────────────────

"""Write text content to a file, creating parent directories as needed."""
def write_file(path: str, content: str) -> str {
    parent = os.path.dirname(os.path.abspath(path));
    if parent {
        os.makedirs(parent, exist_ok=True);
    }
    with open(path, "w", encoding="utf-8") as f {
        f.write(content);
    }
    size_kb = round(os.path.getsize(path) / 1024, 1);
    lines = content.count("\n") + 1;
    return f"Written: {path} ({size_kb} KB, {lines} lines)";
}

"""Write binary content (base64-encoded) to a file."""
def write_binary_file(path: str, b64_content: str) -> str {
    import base64;
    parent = os.path.dirname(os.path.abspath(path));
    if parent {
        os.makedirs(parent, exist_ok=True);
    }
    data = base64.b64decode(b64_content);
    with open(path, "wb") as f {
        f.write(data);
    }
    size_kb = round(len(data) / 1024, 1);
    return f"Written (binary): {path} ({size_kb} KB)";
}

"""Read a file and return its text content."""
def read_file(path: str) -> str {
    if not os.path.exists(path) {
        return f"ERROR: File not found: {path}";
    }
    size = os.path.getsize(path);
    if size > 100_000 {
        # Truncate large files so they don't flood context
        with open(path, "r", encoding="utf-8", errors="replace") as f {
            content = f.read(100_000);
        }
        return content + f"\n\n[...truncated — file is {round(size/1024,1)} KB total]";
    }
    with open(path, "r", encoding="utf-8", errors="replace") as f {
        return f.read();
    }
}

"""List files in a directory."""
def list_dir(path: str = ".") -> str {
    if not os.path.exists(path) {
        return f"ERROR: Directory not found: {path}";
    }
    entries = [];
    for entry in sorted(os.listdir(path)) {
        full = os.path.join(path, entry);
        if os.path.isdir(full) {
            entries.append(f"{entry}/");
        } else {
            size_kb = round(os.path.getsize(full) / 1024, 1);
            entries.append(f"{entry}  ({size_kb} KB)");
        }
    }
    return "\n".join(entries) if entries else "(empty)";
}

# ── Code execution ─────────────────────────────────────────────────────────────

"""Execute a Python script and return its stdout + stderr.

The script is written to a temp file and run with the same Python
interpreter that powers the Jac runtime, so all installed packages
(pandas, pillow, python-pptx, reportlab, etc.) are available.
"""
def execute_python(code: str) -> str {
    tmp = tempfile.NamedTemporaryFile(
        mode="w", suffix=".py", delete=False, encoding="utf-8"
    );
    tmp.write(code);
    tmp.close();
    try {
        r = subprocess.run(
            [_PYTHON, tmp.name],
            capture_output=True,
            text=True,
            timeout=180,
            cwd=os.getcwd()
        );
        out = (r.stdout or "") + (r.stderr or "");
        if r.returncode != 0 and not out.strip() {
            out = f"Process exited with code {r.returncode} (no output)";
        }
        return out.strip() or f"Script completed. Exit code: {r.returncode}";
    } except subprocess.TimeoutExpired {
        return "ERROR: Script timed out after 180 seconds.";
    } except Exception as e {
        return f"ERROR: Could not run script: {e}";
    } finally {
        os.unlink(tmp.name);
    }
}

"""Run a shell command via bash and return its stdout + stderr."""
def bash(command: str) -> str {
    # npm install and pip install can be slow — allow extra time
    slow_cmds = ["npm install", "pip install", "npm run build", "npm run bundle"];
    timeout = 300 if any([kw in command for kw in slow_cmds]) else 120;
    try {
        r = subprocess.run(
            command,
            shell=True,
            executable="/bin/bash",
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=os.getcwd()
        );
        out = (r.stdout or "") + (r.stderr or "");
        if r.returncode != 0 and not out.strip() {
            out = f"Command failed. Exit code: {r.returncode}";
        }
        return out.strip() or f"Done. Exit code: {r.returncode}";
    } except subprocess.TimeoutExpired {
        return f"ERROR: Command timed out after {timeout}s: {command[:80]}";
    } except Exception as e {
        return f"ERROR: {e}";
    }
}

"""Execute Node.js / TypeScript code and return its stdout + stderr."""
def execute_node(code: str) -> str {
    tmp = tempfile.NamedTemporaryFile(
        mode="w", suffix=".js", delete=False, encoding="utf-8"
    );
    tmp.write(code);
    tmp.close();
    try {
        r = subprocess.run(
            [_NODE, tmp.name],
            capture_output=True,
            text=True,
            timeout=120,
            cwd=os.getcwd()
        );
        out = (r.stdout or "") + (r.stderr or "");
        if r.returncode != 0 and not out.strip() {
            out = f"Process exited with code {r.returncode} (no output)";
        }
        return out.strip() or f"Script completed. Exit code: {r.returncode}";
    } except subprocess.TimeoutExpired {
        return "ERROR: Node.js script timed out after 120 seconds.";
    } except FileNotFoundError {
        return "ERROR: node not found in PATH. Install Node.js first.";
    } except Exception as e {
        return f"ERROR: {e}";
    } finally {
        os.unlink(tmp.name);
    }
}
