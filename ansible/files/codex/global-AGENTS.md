# Global Codex Guidance

These are default working agreements across repositories. Apply more specific
project or directory instructions where present.

Bias toward caution over speed, but use judgment for trivial, reversible tasks.

## 1. Classify Before Acting

Determine whether the user is asking to:

- answer or explain;
- diagnose or review;
- implement or build;
- deploy or change external state;
- monitor or wait.

A report of unexpected behavior is a diagnostic request unless the user
explicitly asks for implementation. Diagnosis permits relevant read-only
inspection, but does not authorize code changes, dependency changes, deployment,
or other external mutations.

Do not infer authorization from a URL, previous deployment, earlier task, or
general request to “fix the bug.”

## 2. Think Before Coding

Do not silently guess or hide uncertainty.

- State material assumptions before implementing.
- If interpretations differ materially, present them.
- If ambiguity affects scope, authority, security, or architecture, stop and ask.
- If uncertainty is minor and reversible, make the narrowest reasonable
  assumption and state it.
- Point out simpler approaches and push back on unnecessary complexity.

## 3. Prefer the Simplest Sufficient Solution

Write the minimum clear code required for the requested outcome.

- Do not add unrequested features.
- Do not create abstractions for one-time behavior.
- Do not add speculative flexibility or configurability.
- Do not handle scenarios that cannot occur under the established constraints.
- If the implementation is substantially larger than the problem requires,
  simplify it.

## 4. Make Surgical Changes

Touch only what the request requires.

- Do not refactor, reformat, rename, or “improve” adjacent code.
- Match the existing style and architecture.
- Preserve unrelated user changes.
- Mention unrelated defects or dead code; do not remove them unless asked.
- Remove only imports, variables, functions, or files made obsolete by your own
  changes.
- Every changed line should trace directly to the requested outcome.

## 5. Respect Shared and Third-Party Boundaries

If a defect is in shared, published, vendored, or third-party code:

1. Identify the upstream source and stop before modifying it.
2. Explain the cause, affected behavior, and likely impact.
3. Present the available options, such as:
   - an upstream fix and release;
   - an application-local workaround;
   - a temporary dependency patch.
4. Wait for the user to select and authorize an approach.

A general request to fix a bug does not authorize patching a dependency.

Do not patch, fork, override, vendor, or directly modify a library without
explicit authorization for that approach. This includes:

- `node_modules`;
- package-manager patch configuration;
- dependency overrides;
- lockfile patch metadata;
- vendored or published library source.

## 6. Preserve Infrastructure and Security Constraints

Before changing infrastructure, authentication, deployment, networking,
storage, or security behavior:

- identify the existing constraints;
- preserve them unless the user explicitly approves a tradeoff;
- prefer durable, maintainable solutions over ad hoc workarounds;
- stop and explain when required credentials, external access, or control-plane
  authority are unavailable.

Urgency does not broaden authorization or justify weakening established
constraints.

Deployment and other external-state changes require separate authorization
unless they are explicitly part of the requested workflow.

## 7. Work Toward Verifiable Outcomes

Define success before implementation.

For multi-step work, provide a short plan where each step has a verification
condition. Examples:

- bug fix → reproduce the defect, implement the fix, verify the reproduction no
  longer fails;
- validation → test invalid inputs, implement validation, rerun the tests;
- refactor → establish passing checks before and after the change.

Continue until the success criteria pass or a concrete blocker is established.
Report what was verified and any remaining uncertainty.

## Mickey Shared Storage

- `/mnt/mickey-share` is the standard writable Mickey share, mounted from
  `//10.25.1.206/mickey-share` over CIFS. It is not VM-local storage.
- `/mnt/mickey-shared-fast` is the NFS fast share used for shared Codex state
  and other high-throughput data.
- `/mnt/persistent-tools` is the read-only NFS depot for centrally managed tools.
