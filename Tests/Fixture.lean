import LeanProofAudit

namespace LeanProofAuditFixture

axiom unavailable : False

theorem directUse : False := unavailable

theorem transitiveUse : False := directUse

theorem unfinished : True := by
  sorry

def helper : Nat := 1

theorem helperUse : helper = 1 := rfl

#audit deps transitiveUse
#audit impact unavailable
#audit footprint transitiveUse
#audit footprint unfinished
#audit json transitiveUse
#audit risks
#audit write-report ".lake/build/audit-report.md"
#audit write-graph ".lake/build/audit-graph.dot"

end LeanProofAuditFixture
