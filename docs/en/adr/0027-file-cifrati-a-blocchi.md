# ADR-0027 — Files encrypted in AES-GCM blocks

- Status: accepted
- Date: 2026-10-12
- Spec references: sec. 9.1, 9.2, 9.4; ADR-0007

## Context
The spec calls for per-item files encrypted with AES-GCM (CryptoKit). A one-hour call produces tens of MB of audio: a single `AES.GCM.seal` would require keeping everything in memory, both when encrypting and when reading. Truncated, reordered, or swapped files must also be detected.

## Decision
- Format `IAGOENC` version 1: a header (`IAGOENC`, version, block size) followed by 1 MB blocks, each `nonce (12) | ciphertext | tag (16)`, with a random nonce per block.
- The authenticated data of each block includes the header, a **context** (the relative path, e.g. `<itemId>/mic.m4a.enc`), the block index, and the "last block" flag. Swapping files, reordering or removing blocks, truncating at a block boundary, or appending data makes decryption fail.
- An empty file is a single empty block marked as last.
- Streaming encryption and decryption, writing to a temporary file and moving it atomically at the end: an error never leaves partial files.
- The key is the item's key (ADR-0028). The SHA-256 recorded in `asset.sha256` is that of the **plaintext content**, recomputed on every read (FR-54).
- Files are named `<original name>.enc` in `Items/<itemId>/`.

## Consequences
- Constant memory (about 1 MB) for files of any length.
- Overhead of 28 bytes per MB, negligible.
- For playback, audio is decrypted into `tmp/playback/`, cleaned up when playback ends and at launch (sec. 9.4).
- A format change requires a new version in the header and reading of previous versions.
