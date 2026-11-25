# LeanProofAudit

LeanProofAudit is a static program-analysis tool for Lean 4 projects. It
analyzes elaborated declarations and proof terms to report dependency impact,
proof footprints, and transitive use of axioms or unsafe declarations.

## Motivation

Lean projects are programs. Their definitions, theorem statements, proof
terms, typeclass instances, and tactic-generated dependencies form a large
resolved graph. Changes to a low-level lemma can affect many downstream
proofs, and a theorem can accidentally depend on `sorryAx` or another
unwanted assumption through several layers of lemmas.

LeanProofAudit treats this graph as an analysis target rather than scanning
source text. The planned analyses are:

- declaration dependency graph construction;
- transitive axiom and unsafe-declaration propagation;
- reverse impact slicing for changed declarations;
- proof-footprint reports for individual theorems; and
- machine-readable and human-readable analysis output.

## Status

This repository contains the initial project scaffold. Analysis
implementation, command-line entry points, and test fixtures will be added in
subsequent commits.

## Planned Scope

The first version will expose commands equivalent to:

```text
lean-proof-audit deps <declaration>
lean-proof-audit impact <declaration>
lean-proof-audit axioms
```

The implementation will use Lean 4 metaprogramming and environment APIs to
inspect elaborated declarations. Regular-expression-based source scanning is
not part of the analysis design.

## Non-Goals

LeanProofAudit will not implement a Lean kernel, a general theorem prover, or
full symbolic execution of Lean tactic scripts. Those capabilities are
outside the initial scope.

## Build

The project requires Lean 4 and Lake. Once Lean is installed:

```bash
lake build
```

## License

MIT
