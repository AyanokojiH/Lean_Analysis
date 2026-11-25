# LeanProofAudit

LeanProofAudit is a static program-analysis tool for Lean 4 projects. It
analyzes elaborated declarations and proof terms to report proof footprints,
dependency impact, transitive axioms, `sorry` usage, and unsafe dependencies.

The tool does not scan source text with regular expressions. It queries Lean's
elaborated `Environment`, traverses resolved `Expr` constants, and performs
graph analyses over the resulting declaration dependency graph.

## Features

- Build a declaration dependency graph from Lean's elaborated environment.
- Compute direct and transitive dependencies of a theorem or definition.
- Compute forward and reverse impact slices.
- Propagate axioms through arbitrary proof-dependency chains.
- Detect transitive `sorryAx`, nonstandard axioms, and unsafe declarations.
- Generate Markdown risk reports and Graphviz dependency graphs.
- Emit machine-readable JSON footprints.

## Quick Start

Add this repository as a Lake dependency of the Lean project that should be
analyzed, then import the analysis commands:

```lean
import LeanProofAudit
```

The commands can be used directly in a Lean file:

```lean
#audit deps MyTheorem
#audit impact helperLemma
#audit footprint MyTheorem
#audit json MyTheorem
#audit risks
#audit write-report ".lake/build/proof-audit.md"
#audit write-graph ".lake/build/proof-dependencies.dot"
```

Typical output:

```text
## `Example.mainTheorem`
- Kind: `theorem`
- Direct dependencies: 2
- Transitive dependencies: 8
- Contains `sorry`: true
- Axioms:
  - `sorryAx`
- Nonstandard axioms:
  - `sorryAx`
- Unsafe declarations: none
```

## Analysis Pipeline

1. **Elaborated frontend**: read declarations through `Lean.Environment`.
2. **IR extraction**: collect constants occurring in each declaration's type
   and value with `ConstantInfo.getUsedConstantsAsSet`.
3. **Graph construction**: build forward dependencies and a reverse graph for
   declarations in the current module.
4. **Fixed-point propagation**: compute transitive dependency and impact
   closures with visited sets.
5. **Risk classification**: identify axioms, nonstandard axioms, `sorryAx`,
   and unsafe declarations.
6. **Reporting**: render Markdown, JSON, or Graphviz output.

Only current-module declarations are included in risk scans and reverse impact
analysis. Imported modules cannot depend on declarations added later by the
current module, so scanning the complete Lean standard library would add noise
and substantial runtime cost without improving the result.

## Why This Is Program Analysis

Lean declarations, definitions, proof terms, and typeclass instances form a
resolved program graph. LeanProofAudit analyzes this graph rather than
performing text search:

- the analysis input is the elaborated program representation;
- dependency propagation is a work-list/fixed-point analysis;
- reverse impact is a reachability and slicing analysis;
- axiom propagation is a source-to-sink taint analysis;
- the reported results are semantic declaration footprints, not textual
  matches.

## Project Layout

```text
LeanProofAudit.lean          public library entry point
LeanProofAudit/Basic.lean    graph model and analyses
LeanProofAudit/Commands.lean #audit commands
Tests/Fixture.lean           command/output fixture
Tests/AnalysisTest.lean      executable assertions
docs/ARCHITECTURE.md         design and analysis algorithms
```

## Build and Test

Lean 4.14 and Lake are required. The toolchain is pinned in `lean-toolchain`.

```bash
lake build
lake env lean Tests/AnalysisTest.lean
lake env lean Tests/Fixture.lean
```

Or run the complete test script:

```bash
sh Tests/run-tests.sh
```

## Limitations

- The current reverse-impact scope is the current Lean module.
- Import minimization and automatic proof repair are not implemented.
- Tactic-script semantic analysis is not implemented; dependencies are taken
  from the elaborated proof term produced by Lean.
- Standard foundational axioms (`propext`, `Quot.sound`, and
  `Classical.choice`) are reported separately from nonstandard axioms.

## License

MIT
