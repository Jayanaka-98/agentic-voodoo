"""Example agent — drives a skill file end-to-end via byLLM tool-calling.

Contract expected by voodoo-bench:
  - def run(task: str, llm: Model, skill: str) -> str
  - optional glob DEFAULT_TASK: str
"""

import os;
import subprocess;
import from byllm.lib { Model }


"""Execute Python code and return stdout/stderr."""
def execute_python(code: str) -> str {
    r = subprocess.run(
        ["python3", "-c", code],
        capture_output=True, text=True, timeout=120
    );
    return f"STDOUT:\n{r.stdout}\nSTDERR:\n{r.stderr}";
}

"""Run a shell command and return its combined output."""
def bash(cmd: str) -> str {
    r = subprocess.run(
        cmd, shell=True, capture_output=True, text=True, timeout=120
    );
    return f"STDOUT:\n{r.stdout}\nSTDERR:\n{r.stderr}";
}

"""Write content to path, creating parent dirs as needed."""
def write_file(path: str, content: str) -> str {
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True);
    with open(path, "w") as f {
        f.write(content);
    }
    return f"Wrote {len(content)} chars to {path}";
}

"""Read and return the contents of path."""
def read_file(path: str) -> str {
    with open(path, "r") as f {
        return f.read();
    }
}


glob DEFAULT_TASK: str = "Create a one-page PDF saying 'Hello voodoo-bench' and save it as hello.pdf";


"""Execute the skill instructions to complete the user's task using the available tools."""
def _run_task(skill_text: str, user_task: str, llm: Model) -> str by llm(
    model=llm,
    tools=[execute_python, bash, write_file, read_file],
    max_react_iterations=30
);

sem _run_task = "Follow skill_text instructions precisely to complete user_task end-to-end. Use tools iteratively until the artifact is fully created and saved.";
sem _run_task.skill_text = "Complete skill instructions defining tools, workflow, and best practices for this task type.";
sem _run_task.user_task = "The specific artifact the user wants created, with all requirements.";


"""Voodoo-bench entry point — invoked by the CLI for every benchmark run."""
def run(task: str, llm: Model, skill: str) -> str {
    return _run_task(skill, task, llm);
}
