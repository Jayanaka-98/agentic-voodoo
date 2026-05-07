"""Build a byLLM Model from CLI flags.

Spec format on `--model`:
  openai/gpt-4o
  anthropic/claude-opus-4-7
  anthropic/claude-sonnet-4-6
  vllm:Qwen/Qwen2.5-72B-Instruct          (forwarded as litellm hosted_vllm/)
  ollama/llama3.1                         (litellm ollama/ prefix)

For vLLM and any OpenAI-compatible local server, pass --base-url.
Extra kwargs (temperature, max_tokens, etc.) come from --model-arg key=value.
"""

import os;
import from byllm.lib { Model }


"""Coerce a string to bool/int/float when it cleanly parses, else leave as str."""
def _coerce(v: str) -> any {
    if v.lower() in ("true", "false") {
        return v.lower() == "true";
    }
    try {
        if "." in v {
            return float(v);
        }
        return int(v);
    } except ValueError {
        return v;
    }
}


"""Return a byllm.lib.Model instance configured for the given spec."""
def build_model(
    spec: str,
    base_url: str = "",
    api_key: str = "",
    extra: list[str] | None = None
) -> Model {
    # `call_params` is the byllm bag for litellm-bound options like base_url,
    # temperature, max_tokens, etc. Top-level Model kwargs are limited to
    # model_name / config / api_key / ctx_window — anything else belongs here.
    call_params: dict[str, any] = {};
    if extra is not None {
        for pair in extra {
            if "=" not in pair {
                raise ValueError(f"--model-arg must be key=value, got: {pair!r}");
            }
            parts: list[str] = pair.split("=", 1);
            k: str = parts[0].strip();
            v: str = parts[1].strip();
            call_params[k] = _coerce(v);
        }
    }

    if spec.startswith("vllm:") {
        model_name = "hosted_vllm/" + spec[len("vllm:"):];
        if not base_url {
            raise ValueError("--base-url is required when --model uses the vllm: prefix");
        }
    } else {
        model_name = spec;
    }

    if base_url {
        call_params.setdefault("base_url", base_url);
    }

    resolved_api_key: str = api_key;
    if not resolved_api_key and spec.startswith("vllm:") {
        # vLLM servers usually accept any non-empty key.
        resolved_api_key = os.environ.get("VLLM_API_KEY", "EMPTY");
    }

    return Model(
        model_name=model_name,
        api_key=resolved_api_key,
        call_params=call_params
    );
}
