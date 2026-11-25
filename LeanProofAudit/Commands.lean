import LeanProofAudit.Basic

open Lean Elab Command

namespace LeanProofAudit

syntax (name := auditDepsCmd) "#audit" "deps" ident : command
syntax (name := auditImpactCmd) "#audit" "impact" ident : command
syntax (name := auditFootprintCmd) "#audit" "footprint" ident : command
syntax (name := auditJsonCmd) "#audit" "json" ident : command
syntax (name := auditRisksCmd) "#audit" "risks" : command
syntax (name := auditReportCmd) "#audit" "write-report" str : command
syntax (name := auditGraphCmd) "#audit" "write-graph" str : command

private def renderNames (names : Array Name) : String :=
  if names.isEmpty then
    "none"
  else
    String.intercalate ", " <| names.toList.map fun name => s!"`{name}`"

private def commandGraph : CommandElabM DependencyGraph := do
  return DependencyGraph.buildLocal (← getEnv)

private def resolveDeclaration (id : Syntax) : CommandElabM Name :=
  liftCoreM <| realizeGlobalConstNoOverloadWithInfo id

private def footprintOrThrow
    (env : Environment) (name : Name) : CommandElabM Footprint := do
  match footprintOf? env name with
  | some result => return result
  | none => throwError s!"unknown declaration '{name}'"

private def riskReport (env : Environment) : CommandElabM String := do
  let dependencyGraph := DependencyGraph.buildLocal env
  let names := dependencyGraph.declarations.toList
    |>.map (fun entry => entry.1)
    |>.filter (fun name => !name.isInternal)
    |>.toArray
    |>.qsort (fun left right => left.toString < right.toString)
  let mut lines : Array String := #[]
  for name in names do
    if let some result := footprintOf? env name then
      let risky := result.containsSorry ||
        !result.nonstandardAxioms.isEmpty ||
        !result.unsafeDeclarations.isEmpty
      if risky then
        let flags : Array String :=
          (#[]).push (if result.containsSorry then "sorry" else "")
            |>.push (if result.nonstandardAxioms.isEmpty then ""
                     else s!"axioms={renderNames result.nonstandardAxioms}")
            |>.push (if result.unsafeDeclarations.isEmpty then ""
                     else s!"unsafe={renderNames result.unsafeDeclarations}")
        let flags := flags.filter (· != "")
        lines := lines.push
          s!"- `{name}`: {String.intercalate "; " flags.toList}"
  if lines.isEmpty then
    return "LeanProofAudit: no local proof risks found"
  else
    return s!"LeanProofAudit risks\n{String.intercalate "\n" lines.toList}"

@[command_elab auditDepsCmd]
def elabAuditDeps : CommandElab
  | `(#audit deps $id:ident) => do
    let name ← resolveDeclaration id
    let env ← getEnv
    let info ← match env.find? name with
      | some info => pure info
      | none => throwError s!"unknown declaration '{name}'"
    let dependencies := DependencyGraph.directDependencies env info
    logInfo m!"Direct dependencies of `{name}` ({declarationKind info}): {renderNames dependencies}"
  | _ => throwUnsupportedSyntax

@[command_elab auditImpactCmd]
def elabAuditImpact : CommandElab
  | `(#audit impact $id:ident) => do
    let name ← resolveDeclaration id
    let dependencyGraph ← commandGraph
    let direct := dependencyGraph.directDependents name
    let transitive := dependencyGraph.transitiveDependents name
    logInfo m!"Impact of `{name}`\n- Direct dependents: {renderNames direct}\n- Transitive dependents: {renderNames transitive}"
  | _ => throwUnsupportedSyntax

@[command_elab auditFootprintCmd]
def elabAuditFootprint : CommandElab
  | `(#audit footprint $id:ident) => do
    let name ← resolveDeclaration id
    let env ← getEnv
    let result ← footprintOrThrow env name
    logInfo result.toMarkdown
  | _ => throwUnsupportedSyntax

@[command_elab auditJsonCmd]
def elabAuditJson : CommandElab
  | `(#audit json $id:ident) => do
    let name ← resolveDeclaration id
    let env ← getEnv
    let result ← footprintOrThrow env name
    logInfo result.toJson.pretty
  | _ => throwUnsupportedSyntax

@[command_elab auditRisksCmd]
def elabAuditRisks : CommandElab
  | `(#audit risks) => do
    let env ← getEnv
    logInfo (← riskReport env)
  | _ => throwUnsupportedSyntax

@[command_elab auditReportCmd]
def elabAuditReport : CommandElab
  | `(#audit write-report $path:str) => do
    let env ← getEnv
    let renderedReport ← riskReport env
    liftIO <| IO.FS.writeFile (System.FilePath.mk path.getString)
      (renderedReport ++ "\n")
    logInfo m!"Wrote proof audit report to `{path.getString}`"
  | _ => throwUnsupportedSyntax

@[command_elab auditGraphCmd]
def elabAuditGraph : CommandElab
  | `(#audit write-graph $path:str) => do
    let env ← getEnv
    let dependencyGraph := DependencyGraph.buildLocal env
    liftIO <| IO.FS.writeFile (System.FilePath.mk path.getString)
      dependencyGraph.toDot
    logInfo m!"Wrote dependency graph to `{path.getString}`"
  | _ => throwUnsupportedSyntax

end LeanProofAudit
