import LeanProofAudit

open Lean
open LeanProofAudit

namespace LeanProofAuditTests

axiom unavailable : False

theorem directUse : False := unavailable

theorem transitiveUse : False := directUse

theorem unfinished : True := by
  sorry

run_cmd do
  let env ← getEnv

  let some directFootprint := footprintOf? env ``transitiveUse
    | throwError "missing transitiveUse footprint"
  unless directFootprint.nonstandardAxioms.contains ``unavailable do
    throwError "unavailable axiom was not propagated to transitiveUse"

  let some sorryFootprint := footprintOf? env ``unfinished
    | throwError "missing unfinished footprint"
  unless sorryFootprint.containsSorry do
    throwError "sorryAx was not detected"

  let dependencyGraph := DependencyGraph.buildLocal env
  let dependents := dependencyGraph.transitiveDependents ``unavailable
  unless dependents.contains ``directUse &&
      dependents.contains ``transitiveUse do
    throwError "reverse impact analysis missed transitive dependents"

  logInfo "LeanProofAudit analysis tests passed"

end LeanProofAuditTests
