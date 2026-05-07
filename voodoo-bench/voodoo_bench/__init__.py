"""voodoo-bench — Lazy Loading."""

import importlib.util
import sys

# jaclang is a hard runtime dependency (provided by jaseci) — bail loudly
# if it's missing, since every .jac file in this package needs the
# JacMetaImporter that jaclang installs on import.
if importlib.util.find_spec("jaclang") is None:
    sys.stderr.write(
        "ImportError: jaclang is required for voodoo-bench to function. "
        "Install it via `pip install jaseci` (which provides jaclang) and retry.\n"
    )
    sys.exit(1)

# Importing jaclang here registers the meta-importer for .jac files. The
# `if "jaclang" not in sys.modules` guard mirrors byllm's pattern: if
# jaclang itself is mid-init and loading us as a plugin, don't re-import.
if "jaclang" not in sys.modules:
    import jaclang  # noqa: F401
