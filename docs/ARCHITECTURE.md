# Architecture

## Overview

LeanProofAudit performs static analysis over Lean 4's elaborated environment.
It deliberately avoids parsing source files as text. The frontend is Lean's
own elaborator and kernel environment, which already resolve names, implicit
arguments, typeclass instances, and proof terms.

## Program Representation

Each analyzed declaration is represented by:

```text
Declaration :=
  name
  kind
  isUnsafe
  directDependencies
```

Direct dependencies are all constants appearing in the declaration type or
value. Lean's `ConstantInfo.getUsedConstantsAsSet` performs the expression
traversal.

The forward graph maps declarations to dependencies. The reverse graph maps a
declaration to declarations that depend on it.

## Analyses

### Transitive Dependency Closure

Starting from a declaration, a work-list traversal follows dependency edges
until no unseen declarations remain. The result excludes the root.

### Reverse Impact Slice

Starting from a changed declaration, a reverse traversal follows dependents.
The result is the set of current-module declarations whose proofs may need to
be revisited.

### Axiom and Unsafe Propagation

The transitive footprint is classified into:

- axiomatic dependencies;
- nonstandard axioms;
- unsafe declarations;
- direct or transitive use of `sorryAx`.

Standard foundational axioms are separated from project-specific assumptions.

### Reporting

The same analysis result can be rendered as:

- Markdown for human review;
- JSON for editor/tool integration;
- Graphviz DOT for dependency visualization.

## Complexity and Scope

Single-declaration dependency and footprint queries are computed on demand
from `Environment.find?`. Reverse impact scans declarations added by the
current module only. This keeps analysis practical because imported modules
cannot depend on new declarations from the module currently being elaborated.

## Course Knowledge Mapping

- Work-list and fixed-point reasoning from dataflow analysis;
- call-graph-style dependency construction;
- context of declaration kinds and module boundaries;
- source-to-sink taint propagation for axioms;
- reverse reachability for impact slicing.
