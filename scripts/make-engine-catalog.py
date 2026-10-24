#!/usr/bin/env python3
"""Prints the Swift entries of the engine catalog (ADR-0048) for Hugging Face MLX repos, pinned to their current
commit: every file with size and SHA-256. Large files take the SHA-256 from Git LFS; small ones are downloaded and
hashed. Usage: scripts/make-engine-catalog.py mlx-community/Qwen3.5-4B-4bit [...]"""
import hashlib
import json
import sys
import urllib.request

SKIP = {".gitattributes", "README.md", "video_preprocessor_config.json"}


def get(url):
    with urllib.request.urlopen(url) as response:
        return response.read()


for repo in sys.argv[1:]:
    info = json.loads(get(f"https://huggingface.co/api/models/{repo}"))
    revision = info["sha"]
    tree = json.loads(get(f"https://huggingface.co/api/models/{repo}/tree/{revision}?recursive=1"))
    print(f"// {repo} @ {revision}")
    print(f'repo: "{repo}", revision: "{revision}",')
    print("files: [")
    for entry in tree:
        if entry["type"] != "file" or entry["path"] in SKIP:
            continue
        if entry.get("lfs"):
            sha = entry["lfs"]["oid"]
            size = entry["lfs"]["size"]
        else:
            data = get(f"https://huggingface.co/{repo}/resolve/{revision}/{entry['path']}")
            sha = hashlib.sha256(data).hexdigest()
            size = len(data)
        print(f'    .init(path: "{entry["path"]}", size: {size}, sha256: "{sha}"),')
    print("],")
