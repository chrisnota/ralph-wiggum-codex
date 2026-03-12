# Ralph Wiggum for Codex

A Codex CLI version of the Ralph Wiggum loop. It repeatedly runs the same prompt
via `codex exec` until a completion promise is detected, a configured stop rule
is reached, or the loop is cancelled.

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
# user install (default)
make install
# or install system-wide
sudo make install PREFIX=/usr/local
```

Uninstall:

```bash
# user uninstall (default)
make uninstall
# or uninstall system-wide
sudo make uninstall PREFIX=/usr/local
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

Direct mode supports:

- `--max-iterations N`
- `--max-timeout-seconds N`
- `--completion-promise TEXT`

If `ralph loop` is run with no prompt on a TTY, Ralph asks for a prompt and then
starts the normal loop with that exact prompt. Multi-line input is supported;
finish input with Ctrl-D on a new line:

```bash
ralph loop
```

For multi-line prompts, use stdin instead:

```bash
cat PROMPT.md | ralph loop --completion-promise "COMPLETE" -- --model o3
```

Important: If you set `--completion-promise`, your prompt MUST instruct Codex to
output the exact `<promise>...</promise>` tag only when the completion criteria
are fully satisfied. Ralph does not add this instruction for you.

Example prompt snippet:

```
When complete, output EXACTLY:
<promise>DONE</promise>
```

Run with a wall-clock timeout:

```bash
ralph loop "Fix the auth bug" --max-timeout-seconds 1800 -- --model o3
```

Pass Codex flags after `--`:

```bash
ralph loop Fix auth bug --max-iterations 10 -- --model o3 --sandbox workspace-write
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

Matching is exact after whitespace normalization.

Stop rules:

- `--max-iterations` stops before starting an iteration that would exceed the count
- `--max-timeout-seconds` is a cooperative wall-clock timeout from loop start
- if both are set, Ralph stops when either one is reached
- if no completion promise or stop rule is set, the loop runs until you cancel it

## State file

A state file is written to `.codex/ralph-loop.local.md` in the current repo.
This is used to track the iteration count and loop settings.

## Notes

- Do not pass `--output-last-message` to `codex exec`; Ralph uses it internally.
- If `codex exec` fails, the loop stops and the state file is removed.
