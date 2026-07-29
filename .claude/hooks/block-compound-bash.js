#!/usr/bin/env node
// PreToolUse hook for the Bash tool: denies commands that chain multiple
// commands together via shell separators (; && || or newline).
// Pipes (|) are allowed since they stream data between commands rather
// than sequencing independent commands.
// This is a blunt substring check, not a real shell parser — a separator
// character inside a quoted string (e.g. `git commit -m "a; b"`) will also
// be blocked. Loosen the regex below if that's too strict for your workflow.

let data = '';
process.stdin.on('data', (chunk) => (data += chunk));
process.stdin.on('end', () => {
  let input;
  try {
    input = JSON.parse(data);
  } catch {
    process.exit(0);
  }

  const command = (input.tool_input && input.tool_input.command) || '';
  const chainPattern = /;|&&|\|\||\n/;

  if (chainPattern.test(command)) {
    process.stdout.write(
      JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          permissionDecision: 'deny',
          permissionDecisionReason:
            'Chained/compound commands (using ; && || or newlines) are blocked by policy. Pipes (|) are allowed.',
        },
      })
    );
  }

  process.exit(0);
});
