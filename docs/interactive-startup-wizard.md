# Interactive Startup Wizard Design

## Goal

Add an interview-style startup flow before the Ralph loop begins. The wizard
asks the user a small number of focused questions, uses `codex exec` between
steps to structure or refine that information, shows the final generated prompt
for confirmation, optionally accepts refinement feedback, and then starts the
existing loop engine.

This document is design-only. It does not change the current CLI behavior yet.

## Primary Constraints

- Keep the existing non-interactive path intact for scripting and power users.
- Every preflight `codex exec` call must return strict JSON, with no prose or
  markdown.
- Bash should not parse free text. Use `python3` to parse and validate JSON.
- The wizard should fail closed. If a preflight response is malformed, tell the
  user and allow retry or exit.
- The existing loop logic in `cmd_loop` should remain the execution engine. The
  wizard should produce a finalized prompt and finalized run settings, then hand
  them to that engine.

## Proposed Command Surface

Recommended behavior:

- `ralph loop <prompt...>` keeps the current direct behavior.
- `ralph loop` with no prompt and a TTY starts the interactive wizard.
- `ralph loop --interactive` also starts the wizard explicitly.
- `ralph loop --interactive <goal...>` starts the wizard and treats the trailing
  words as the initial answer to "What are you trying to do?"
- If stdin is piped, stay in non-interactive mode.

This keeps automation stable while making the new flow discoverable.

## User Experience

### High-Level Flow

1. Ask: "What are you trying to do?"
2. Run `codex exec` to generate 0 to 4 targeted follow-up questions.
3. Ask those follow-up questions and capture answers.
4. Ask: "What is the acceptance criteria?"
5. Run `codex exec` to synthesize a final working prompt package.
6. Ask: "How long should Ralph run for?"
7. Run `codex exec` to normalize the user response into run settings.
8. Show a review screen with:
   - final generated prompt
   - completion promise
   - max iterations
   - max timeout in seconds
9. Ask for confirmation:
   - empty input, `y`, or `yes` starts the loop
   - `n`, `no`, `q`, `quit`, or `abort` exits without starting
   - any non-empty feedback is treated as prompt refinement input
   - prompt refinement is the only edit path in the first version
10. If refinement feedback is provided, run `codex exec` again to refine the
    prompt package, then show the review screen again.

### Example Transcript

```text
$ ralph loop --interactive

What are you trying to do?
> Build a REST API for todos with auth and tests

I need a bit more detail.
1. Which stack or framework should be used?
> FastAPI
2. What persistence layer should be used?
> PostgreSQL
3. Are there constraints around deployment or local dev?
> Docker Compose for local dev

What is the acceptance criteria?
> CRUD endpoints work, auth required, tests pass, and README has setup steps

How long should Ralph run for?
> Stop after about 45 minutes or 15 iterations, whichever comes first

Review
Prompt:
<generated prompt here>

Completion promise: API_READY
Max iterations: 15
Max timeout seconds: 2700

Press Enter to start, type abort to cancel, or describe what to change:
> Mention OpenAPI docs and seed data

Review
Prompt:
<refined prompt here>
...
```

## Wizard State Model

The interactive flow should maintain a structured in-memory state before the
normal Ralph state file is written.

Suggested fields:

```json
{
  "goal": "string",
  "follow_up_questions": [
    {
      "id": "stack",
      "question": "Which stack or framework should be used?"
    }
  ],
  "follow_up_answers": {
    "stack": "FastAPI"
  },
  "acceptance_criteria": "string",
  "prompt_package": {
    "prompt": "string",
    "completion_promise": "string or null",
    "requires_completion_promise": true
  },
  "run_settings": {
    "run_forever": false,
    "max_iterations": 15,
    "max_timeout_seconds": 2700
  }
}
```

Nothing should be written to `.codex/ralph-loop.local.md` until the user
confirms the final review screen.

## Preflight `codex exec` Steps

### Common Output Rules

Every preflight call should include these rules in the prompt:

- Return exactly one JSON object.
- Do not wrap the JSON in markdown fences.
- Do not include any explanation before or after the JSON.
- Use `null` for unknown values.
- If the input is ambiguous, set an explicit clarification field instead of
  guessing.

Every JSON response should be parsed by `python3`, validated for required keys,
and rejected if it contains the wrong shape.

## Step 1: Follow-Up Question Generation

Purpose:

- Turn the user's initial goal into 0 to 4 concrete follow-up questions.
- Avoid asking obvious or redundant questions.
- Focus on details that materially change the generated implementation prompt.

Suggested JSON contract:

```json
{
  "questions": [
    {
      "id": "stack",
      "question": "Which stack or framework should be used?"
    },
    {
      "id": "persistence",
      "question": "What database or storage should be used?"
    }
  ]
}
```

Validation rules:

- `questions` must be an array.
- Length must be between 0 and 4.
- Each `id` must match `^[a-z0-9_]+$`.
- Each `question` must be a non-empty single question.

Suggested preflight prompt shape:

```text
You are generating follow-up questions for an interactive CLI wizard.

Return exactly one JSON object matching this schema:
{
  "questions": [
    {
      "id": "snake_case_identifier",
      "question": "question text"
    }
  ]
}

Rules:
- Return 0 to 4 questions.
- Ask only questions that will materially improve the final implementation prompt.
- Avoid asking about acceptance criteria; that will be collected separately.
- Do not ask more than one idea in the same question.
- If the user's goal is already specific enough, return zero questions.
- Do not include markdown or explanation.

User goal:
<goal text>
```

## Step 2: Prompt Package Generation

Purpose:

- Synthesize the working Ralph prompt from:
  - original goal
  - follow-up answers
  - acceptance criteria

Suggested JSON contract:

```json
{
  "prompt": "string",
  "completion_promise": "API_READY",
  "requires_completion_promise": true,
  "acceptance_summary": "CRUD API with auth, tests, and setup docs"
}
```

Validation rules:

- `prompt` must be a non-empty string.
- `completion_promise` may be `null`, but a non-null value is preferred.
- `requires_completion_promise` must be boolean.
- If `completion_promise` is non-null, the prompt must explicitly instruct Codex
  to emit the exact `<promise>...</promise>` tag only when fully complete.

Suggested preflight prompt shape:

```text
You are writing a prompt for a repeated Codex execution loop.

Return exactly one JSON object matching this schema:
{
  "prompt": "final prompt text",
  "completion_promise": "PROMISE_TEXT or null",
  "requires_completion_promise": true,
  "acceptance_summary": "brief summary"
}

Rules:
- The prompt should be specific, execution-oriented, and ready to send to Codex.
- The prompt must include the user's goal, constraints, and acceptance criteria.
- If a completion promise is appropriate, include a short uppercase promise token.
- If `completion_promise` is non-null, the prompt must instruct Codex to output
  exactly <promise>VALUE</promise> only when the acceptance criteria are fully met.
- Do not include markdown fences or explanation.

User goal:
<goal text>

Follow-up answers:
<JSON object of question ids to answers>

Acceptance criteria:
<acceptance criteria text>
```

## Step 3: Run Settings Normalization

Purpose:

- Interpret natural language duration limits.
- Normalize them into structured stop conditions.

Suggested JSON contract:

```json
{
  "run_forever": false,
  "max_iterations": 15,
  "max_timeout_seconds": 2700,
  "clarification_needed": false,
  "clarification_question": null
}
```

Validation rules:

- `run_forever` must be boolean.
- If `run_forever` is `false`, at least one of `max_iterations` or
  `max_timeout_seconds` must be non-null.
- If `run_forever` is `true`, both `max_iterations` and
  `max_timeout_seconds` should normally be `null`.
- Values must be positive integers when present.
- If the input is too vague, set `clarification_needed` to `true` and provide a
  single `clarification_question`.

Suggested preflight prompt shape:

```text
You are normalizing natural language run limits for a CLI loop.

Return exactly one JSON object matching this schema:
{
  "run_forever": false,
  "max_iterations": 15,
  "max_timeout_seconds": 2700,
  "clarification_needed": false,
  "clarification_question": null
}

Rules:
- Interpret plain language like "run for 30 minutes" or "try 10 times".
- Interpret explicit requests like "unlimited", "run forever", or "until I stop it"
  as `run_forever: true`.
- Use null for missing values.
- If the request is ambiguous or does not specify any usable stop condition,
  set `clarification_needed` to true and ask one short question.
- Do not include markdown or explanation.

User input:
<run settings text>
```

## Step 4: Prompt Refinement

Purpose:

- Let the user react to the generated prompt without restarting the wizard.
- Use the current prompt package plus user feedback to regenerate only the
  prompt package.

Suggested JSON contract:

```json
{
  "prompt": "string",
  "completion_promise": "API_READY",
  "requires_completion_promise": true,
  "acceptance_summary": "brief summary"
}
```

Suggested preflight prompt shape:

```text
You are refining a prompt for a repeated Codex execution loop.

Return exactly one JSON object matching this schema:
{
  "prompt": "final prompt text",
  "completion_promise": "PROMISE_TEXT or null",
  "requires_completion_promise": true,
  "acceptance_summary": "brief summary"
}

Rules:
- Preserve the core goal and acceptance criteria unless the user's feedback
  explicitly changes them.
- Incorporate the user's requested refinements.
- Keep the prompt concise but specific.
- If `completion_promise` is non-null, the prompt must instruct Codex to output
  exactly <promise>VALUE</promise> only when the acceptance criteria are fully met.
- Do not include markdown or explanation.

Current prompt package:
<current prompt package JSON>

User refinement feedback:
<feedback text>
```

## Timeout and Iteration Semantics

Recommended loop semantics:

- `max_iterations` stops Ralph before starting an iteration that would exceed
  the configured count.
- `max_timeout_seconds` is based on wall-clock time since the actual Ralph loop
  starts, not since the interview begins.
- Timeout is cooperative, not a hard kill. If a single `codex exec` call runs
  past the timeout, Ralph should stop before the next iteration.
- If both limits are set, Ralph stops when either one is reached.
- If `run_forever` is `true`, Ralph runs until completion, manual cancellation,
  or external failure.

## Implementation Notes

### Recommended Internal Structure

Add small helpers rather than growing `cmd_loop` into one large function.

Suggested helper layout inside `bin/ralph`:

- `cmd_loop`: existing direct execution path
- `cmd_interactive_loop`: new wizard entry point
- `prompt_user`: ask one question and read a response
- `run_codex_json_step`: run a preflight `codex exec` call and capture output
- `parse_json_field`: use `python3` to validate and extract JSON fields
- `review_prompt_package`: render the final review screen

### Temporary Files

Use separate temporary files for preflight steps, for example under `.codex`:

- `.codex/ralph-preflight-last-message.txt`
- `.codex/ralph-preflight-response.json`

These should be distinct from the real loop state and safe to overwrite.

### Codex Arg Propagation

All preflight `codex exec` calls should use the same user-supplied Codex args as
the main loop, except for Ralph-owned flags such as `--output-last-message`.
This keeps the model selection and execution behavior consistent across the
wizard and the actual loop.

### Parsing Strategy

Use `python3` for:

- JSON validation
- field extraction
- integer validation
- optional schema checks that are awkward in pure Bash

Avoid using `sed`, `awk`, or regexes to parse JSON.

### Failure Handling

If a preflight `codex exec` step fails:

- show a short error
- offer retry or exit
- do not create the real Ralph loop state file

If JSON validation fails:

- show that the response was malformed
- optionally preserve the raw response in a temp file for debugging
- offer retry

### Review Screen Behavior

For the first version, the review screen should support only:

- start the loop
- abort the wizard
- provide prompt-refinement feedback

Editing runtime settings or acceptance criteria in place is out of scope for
the first implementation.

## Recommended First Implementation Slice

1. Add `--interactive` and the `ralph loop` no-prompt TTY behavior.
2. Implement one preflight `codex exec` step with strict JSON parsing.
3. Add the prompt package generation step.
4. Add run settings normalization with `max_timeout_seconds`.
5. Add the review and refinement loop.
6. Wire the confirmed result into the existing Ralph loop engine.
