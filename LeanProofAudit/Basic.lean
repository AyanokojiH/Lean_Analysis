import Lean
import Lean.Data.Json

open Lean

namespace LeanProofAudit

/-- The declaration classes relevant to proof dependency analysis. -/
inductive DeclarationKind where
  | theorem
  | definition
  | axiom
  | opaque
  | inductive
  | constructor
  | recursor
  | quotient
  | unknown
  deriving BEq, Repr

namespace DeclarationKind

def toString : DeclarationKind → String
  | .theorem => "theorem"
  | .definition => "definition"
  | .axiom => "axiom"
  | .opaque => "opaque"
  | .inductive => "inductive"
  | .constructor => "constructor"
  | .recursor => "recursor"
  | .quotient => "quotient"
  | .unknown => "unknown"

instance : ToString DeclarationKind := ⟨toString⟩

end DeclarationKind

def declarationKind : ConstantInfo → DeclarationKind
  | .thmInfo _ => .theorem
  | .defnInfo _ => .definition
  | .axiomInfo _ => .axiom
  | .opaqueInfo _ => .opaque
  | .inductInfo _ => .inductive
  | .ctorInfo _ => .constructor
  | .recInfo _ => .recursor
  | .quotInfo _ => .quotient

/-- A resolved declaration and its direct constants. -/
structure Declaration where
  name : Name
  kind : DeclarationKind
  isUnsafe : Bool
  dependencies : Array Name
  deriving Repr

/-- Forward and reverse declaration dependency graph. -/
structure DependencyGraph where
  declarations : Std.HashMap Name Declaration
  reverse : Std.HashMap Name NameSet

namespace DependencyGraph

def directDependencies (env : Environment) (info : ConstantInfo) : Array Name :=
  info.getUsedConstantsAsSet.toList
    |>.filter (fun dependency =>
      dependency != info.name && env.contains dependency)
    |>.toArray
    |>.qsort (fun left right => left.toString < right.toString)

private def buildFrom
    (env : Environment)
    (constants : List (Name × ConstantInfo)) : DependencyGraph := Id.run do
  let mut declarations : Std.HashMap Name Declaration := {}
  let mut reverse : Std.HashMap Name NameSet := {}
  for (name, info) in constants do
    let dependencies := directDependencies env info
    declarations := declarations.insert name {
      name
      kind := declarationKind info
      isUnsafe := info.isUnsafe
      dependencies
    }
    for dependency in dependencies do
      reverse := reverse.insert dependency
        ((reverse.getD dependency {}).insert name)
  return { declarations, reverse }

/-- Build the dependency graph for all constants visible in the environment. -/
def build (env : Environment) : DependencyGraph :=
  buildFrom env env.constants.toList

/-- Build the dependency graph for declarations added by the current module. -/
def buildLocal (env : Environment) : DependencyGraph :=
  buildFrom env env.constants.map₂.toList

def declaration? (graph : DependencyGraph) (name : Name) : Option Declaration :=
  graph.declarations.get? name

partial def transitiveDependenciesAux
    (declarations : Std.HashMap Name Declaration)
    (todo : List Name) (seen : NameSet) : NameSet :=
  match todo with
  | [] => seen
  | name :: rest =>
    if seen.contains name then
      transitiveDependenciesAux declarations rest seen
    else
      let seen := seen.insert name
      match declarations.get? name with
      | none => transitiveDependenciesAux declarations rest seen
      | some declaration =>
        transitiveDependenciesAux declarations
          (declaration.dependencies.toList.reverse ++ rest) seen

def transitiveDependencies (graph : DependencyGraph) (root : Name) : Array Name :=
  let all := transitiveDependenciesAux graph.declarations [root] {}
  all.toList
    |>.filter (· != root)
    |>.toArray
    |>.qsort (fun left right => left.toString < right.toString)

partial def transitiveDependentsAux
    (reverse : Std.HashMap Name NameSet)
    (todo : List Name) (seen : NameSet) : NameSet :=
  match todo with
  | [] => seen
  | name :: rest =>
    if seen.contains name then
      transitiveDependentsAux reverse rest seen
    else
      let seen := seen.insert name
      let dependents := (reverse.getD name {}).toList
      transitiveDependentsAux reverse (dependents.reverse ++ rest) seen

def transitiveDependents (graph : DependencyGraph) (root : Name) : Array Name :=
  let all := transitiveDependentsAux graph.reverse [root] {}
  all.toList
    |>.filter (· != root)
    |>.toArray
    |>.qsort (fun left right => left.toString < right.toString)

def directDependents (graph : DependencyGraph) (root : Name) : Array Name :=
  let found := (graph.reverse.getD root {}).toList.toArray
  found.qsort (fun left right => left.toString < right.toString)

def dotEscape (value : String) : String :=
  value.replace "\\" "\\\\" |>.replace "\"" "\\\""

/-- Render the current-module dependency graph as Graphviz DOT. -/
def toDot (graph : DependencyGraph) : String := Id.run do
  let declarations := graph.declarations.toList
    |>.toArray
    |>.qsort (fun left right => left.1.toString < right.1.toString)
  let mut lines : Array String := #["digraph LeanProofAudit {"]
  for (name, declaration) in declarations do
    let color :=
      if declaration.kind == .axiom then "firebrick"
      else if declaration.isUnsafe then "darkorange"
      else if declaration.kind == .theorem then "steelblue"
      else "black"
    lines := lines.push s!"  \"{dotEscape name.toString}\" [color={color}];"
    for dependency in declaration.dependencies do
      if graph.declarations.contains dependency then
        lines := lines.push
          s!"  \"{dotEscape name.toString}\" -> \"{dotEscape dependency.toString}\";"
  lines := lines.push "}"
  return String.intercalate "\n" lines.toList

end DependencyGraph

/-- Direct dependencies of one resolved declaration. -/
def directDependenciesOf? (env : Environment) (name : Name) : Option (Array Name) := do
  let info ← env.find? name
  return DependencyGraph.directDependencies env info

partial def transitiveDependenciesOfAux
    (env : Environment) (todo : List Name) (seen : NameSet) : NameSet :=
  match todo with
  | [] => seen
  | name :: rest =>
    if seen.contains name then
      transitiveDependenciesOfAux env rest seen
    else
      let seen := seen.insert name
      match env.find? name with
      | none => transitiveDependenciesOfAux env rest seen
      | some info =>
        let dependencies :=
          DependencyGraph.directDependencies env info |>.toList
        transitiveDependenciesOfAux env (dependencies.reverse ++ rest) seen

/-- Transitive dependency closure computed directly from the environment. -/
def transitiveDependenciesOf (env : Environment) (root : Name) : Array Name :=
  let all := transitiveDependenciesOfAux env [root] {}
  all.toList
    |>.filter (· != root)
    |>.toArray
    |>.qsort (fun left right => left.toString < right.toString)

/-- A transitive proof/declaration footprint. -/
structure Footprint where
  root : Name
  kind : DeclarationKind
  directCount : Nat
  transitiveCount : Nat
  axioms : Array Name
  nonstandardAxioms : Array Name
  unsafeDeclarations : Array Name
  containsSorry : Bool
  deriving Repr

def standardAxioms : NameSet :=
  ({} : NameSet)
    |>.insert `propext
    |>.insert `Quot.sound
    |>.insert `Classical.choice

def sortNames (names : Array Name) : Array Name :=
  names.qsort (fun left right => left.toString < right.toString)

/-- Compute a footprint without building a graph for unrelated declarations. -/
def footprintOf? (env : Environment) (root : Name) : Option Footprint := do
  let info ← env.find? root
  let dependencies := transitiveDependenciesOf env root
  let names := #[root] ++ dependencies
  let axiomNames := names.filter fun name =>
    env.find? name |>.any (fun dependency =>
      declarationKind dependency == .axiom)
  let unsafeNames := names.filter fun name =>
    env.find? name |>.any (fun dependency => dependency.isUnsafe)
  return {
    root
    kind := declarationKind info
    directCount :=
      (DependencyGraph.directDependencies env info).size
    transitiveCount := dependencies.size
    axioms := sortNames axiomNames
    nonstandardAxioms := sortNames <| axiomNames.filter fun name =>
      !standardAxioms.contains name
    unsafeDeclarations := sortNames unsafeNames
    containsSorry := axiomNames.contains `sorryAx
  }

def footprint? (graph : DependencyGraph) (root : Name) : Option Footprint := do
  let declaration ← graph.declaration? root
  let dependencies ← pure <| graph.transitiveDependencies root
  let names := #[root] ++ dependencies
  let axiomNames := names.filter fun name =>
    graph.declaration? name |>.any (fun dependency =>
      dependency.kind == .axiom)
  let unsafeNames := names.filter fun name =>
    graph.declaration? name |>.any (fun dependency => dependency.isUnsafe)
  return {
    root
    kind := declaration.kind
    directCount := declaration.dependencies.size
    transitiveCount := dependencies.size
    axioms := sortNames axiomNames
    nonstandardAxioms := sortNames <| axiomNames.filter fun name =>
      !standardAxioms.contains name
    unsafeDeclarations := sortNames unsafeNames
    containsSorry := axiomNames.contains `sorryAx
  }

namespace Footprint

def namesJson (names : Array Name) : Json :=
  Json.arr <| names.map fun name => Json.str name.toString

def toJson (footprint : Footprint) : Json :=
  Json.mkObj [
    ("root", Json.str footprint.root.toString),
    ("kind", Json.str footprint.kind.toString),
    ("directDependencies", Json.num footprint.directCount),
    ("transitiveDependencies", Json.num footprint.transitiveCount),
    ("axioms", namesJson footprint.axioms),
    ("nonstandardAxioms", namesJson footprint.nonstandardAxioms),
    ("unsafeDeclarations", namesJson footprint.unsafeDeclarations),
    ("containsSorry", Json.bool footprint.containsSorry)
  ]

def renderNames (title : String) (names : Array Name) : String :=
  if names.isEmpty then
    s!"- {title}: none"
  else
    let body := String.intercalate "\n" <|
      names.toList.map fun name => s!"  - `{name}`"
    s!"- {title}:\n{body}"

def toMarkdown (footprint : Footprint) : String :=
  String.intercalate "\n" [
    s!"## `{footprint.root}`",
    s!"- Kind: `{footprint.kind}`",
    s!"- Direct dependencies: {footprint.directCount}",
    s!"- Transitive dependencies: {footprint.transitiveCount}",
    s!"- Contains `sorry`: {footprint.containsSorry}",
    renderNames "Axioms" footprint.axioms,
    renderNames "Nonstandard axioms" footprint.nonstandardAxioms,
    renderNames "Unsafe declarations" footprint.unsafeDeclarations
  ]

end Footprint

end LeanProofAudit
