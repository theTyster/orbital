/-
  Formal verification for bug 2156: Dependent effective date persistence.

  Target (C# pseudocode):

    // BUGGY: NonCobraCoverageInfoService.AddDependent
    DependentRelationship addDependentBuggy(depId, depTypeId) {
        return new DependentRelationship { DependentId = depId, DependentTypeId = depTypeId };
        // EffectiveDate defaults to DateTime.MinValue (sentinel)
    }

    // FIXED: NonCobraCoverageInfoService.AddDependent
    DependentRelationship addDependentFixed(depId, depTypeId, effectiveDate) {
        return new DependentRelationship { DependentId = depId, DependentTypeId = depTypeId, EffectiveDate = effectiveDate };
    }

    // REFERENCE (working): CobraCaseService.AddDependent
    DependentRelationship addDependentCobraCase(depId, depTypeId, effectiveDate) {
        return new DependentRelationship { DependentId = depId, DependentTypeId = depTypeId, EffectiveDate = effectiveDate };
    }

  We prove:
    1. The buggy version always produces a sentinel effective date
    2. The fixed version preserves the provided effective date
    3. The fixed version is equivalent to the working CobraCase version w.r.t. effective date handling
-/

set_option autoImplicit false

/-- A simplified model of a date as a natural number (days since epoch).
    Sentinel value 0 represents DateTime.MinValue (0001-01-01). -/
abbrev Date := Nat

/-- Sentinel date representing default(DateTime) = 0001-01-01 -/
def sentinelDate : Date := 0

/-- A simplified DependentRelationship record -/
structure DependentRelationship where
  dependentId : Nat
  dependentTypeId : Nat
  effectiveDate : Date
  deriving Repr, DecidableEq

/-- The BUGGY AddDependent (NonCobraCoverage path): does not set effectiveDate.
    In C#, `DateTime` is a value type defaulting to DateTime.MinValue. -/
def addDependentBuggy (depId : Nat) (depTypeId : Nat) : DependentRelationship :=
  { dependentId := depId, dependentTypeId := depTypeId, effectiveDate := sentinelDate }

/-- The FIXED AddDependent (NonCobraCoverage path): accepts and persists effectiveDate. -/
def addDependentFixed (depId : Nat) (depTypeId : Nat) (effDate : Date) : DependentRelationship :=
  { dependentId := depId, dependentTypeId := depTypeId, effectiveDate := effDate }

/-- The REFERENCE AddDependent (CobraCase path): already works correctly. -/
def addDependentCobraCase (depId : Nat) (depTypeId : Nat) (effDate : Date) : DependentRelationship :=
  { dependentId := depId, dependentTypeId := depTypeId, effectiveDate := effDate }

/-- A valid effective date is any date that is not the sentinel. -/
def isValidEffectiveDate (d : Date) : Prop := d ≠ sentinelDate

/-! ## Theorem 1: The buggy version always produces the sentinel date -/

theorem buggy_always_sentinel (depId depTypeId : Nat) :
    (addDependentBuggy depId depTypeId).effectiveDate = sentinelDate := by
  rfl

/-! ## Theorem 2: The buggy version never produces a valid effective date
    (when a valid date is expected) -/

theorem buggy_loses_valid_date (depId depTypeId : Nat) (effDate : Date)
    (h : isValidEffectiveDate effDate) :
    (addDependentBuggy depId depTypeId).effectiveDate ≠ effDate := by
  simp [addDependentBuggy, sentinelDate, isValidEffectiveDate] at *
  exact Ne.symm h

/-! ## Theorem 3: The fixed version preserves the provided effective date -/

theorem fixed_preserves_date (depId depTypeId : Nat) (effDate : Date) :
    (addDependentFixed depId depTypeId effDate).effectiveDate = effDate := by
  rfl

/-! ## Theorem 4: The fixed version produces a valid effective date
    when given a valid effective date -/

theorem fixed_valid_when_input_valid (depId depTypeId : Nat) (effDate : Date)
    (h : isValidEffectiveDate effDate) :
    isValidEffectiveDate (addDependentFixed depId depTypeId effDate).effectiveDate := by
  simp [addDependentFixed, isValidEffectiveDate] at *
  exact h

/-! ## Theorem 5: The fixed version is equivalent to the CobraCase version -/

theorem fixed_equivalent_to_cobra_case (depId depTypeId : Nat) (effDate : Date) :
    (addDependentFixed depId depTypeId effDate).effectiveDate =
    (addDependentCobraCase depId depTypeId effDate).effectiveDate := by
  rfl

/-! ## Theorem 6: The fixed version preserves all other fields identically to the buggy version -/

theorem fixed_preserves_other_fields (depId depTypeId : Nat) (effDate : Date) :
    (addDependentFixed depId depTypeId effDate).dependentId =
      (addDependentBuggy depId depTypeId).dependentId ∧
    (addDependentFixed depId depTypeId effDate).dependentTypeId =
      (addDependentBuggy depId depTypeId).dependentTypeId := by
  constructor <;> rfl

/-! ## Theorem 7: Full structural equivalence between fixed and CobraCase -/

theorem fixed_structurally_equal_to_cobra_case (depId depTypeId : Nat) (effDate : Date) :
    addDependentFixed depId depTypeId effDate =
    addDependentCobraCase depId depTypeId effDate := by
  rfl
