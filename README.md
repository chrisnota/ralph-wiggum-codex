# Ralph Wiggum for Codex

A Codex CLI version of the Ralph Wiggum loop. It repeatedly runs the same prompt
via `codex exec` until a completion promise is detected or the max iteration
limit is reached.

This mirrors the behavior of the Claude Code plugin:
- The prompt is constant across iterations
- Progress is captured in files and git history, not in prompt changes
- A completion promise (optional) ends the loop

## Requirements

- Linux
- `codex` in PATH
- `python3` in PATH (used to detect `<promise>...</promise>` tags)
- Bash

## Install

### Option A: Makefile (system or user)

```bash
# system install (requires sudo)
sudo make install
# optional: user install without sudo
make install PREFIX=$HOME/.local
```

Uninstall:

```bash
make uninstall PREFIX=/usr/local
```

### Option B: Install script (user)

```bash
./scripts/install.sh
# or choose a prefix
./scripts/install.sh /usr/local
```

Uninstall:

```bash
./scripts/uninstall.sh
```

## Usage

```bash
ralph loop "Build a REST API for todos" --completion-promise "DONE" --max-iterations 20
```

Pass Codex flags after `--`:

```bash
ralph loop Fix auth bug --max-iterations 10 -- --model o3 --sandbox workspace-write
```

Multi-line prompt from stdin:

```bash
cat PROMPT.md | ralph loop --completion-promise "COMPLETE" -- --model o3
```

Cancel a loop:

```bash
ralph cancel
```

Check status:

```bash
ralph status
```

## How completion works

If you set `--completion-promise`, the loop stops only when the last Codex
message contains:

```
<promise>YOUR TEXT</promise>
```

Matching is exact after whitespace normalization. If no promise is set, the loop
runs forever (unless you set `--max-iterations`).

## State file

A state file is written to `.codex/ralph-loop.local.md` in the current repo.
This is used to track the iteration count and loop settings.

## Notes

- Do not pass `--output-last-message` to `codex exec`; Ralph uses it internally.
- If `codex exec` fails, the loop stops and the state file is removed.
