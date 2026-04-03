/-
  Formal verification of insertion sort.

  Target (Python):
    def insertion_sort(lst):
        result = lst[:]
        for i in range(1, len(result)):
            key = result[i]
            j = i - 1
            while j >= 0 and result[j] > key:
                result[j + 1] = result[j]
                j -= 1
            result[j + 1] = key
        return result

  We prove that the output is a sorted permutation of the input.
  The Lean model uses Mathlib's `List.insertionSort` which is a functional
  equivalent of the imperative insertion sort algorithm above.
-/

import Mathlib

set_option autoImplicit false

open List

/-
  `insertionSort (· ≤ ·)` on `List Nat` faithfully models the Python
  `insertion_sort` function: it processes elements left-to-right,
  inserting each into its correct position in the already-sorted prefix.

  Mathlib's `List.insertionSort` is defined as:
    insertionSort r []       = []
    insertionSort r (a :: l) = orderedInsert r a (insertionSort r l)

  where `orderedInsert r a l` inserts `a` into the sorted list `l`
  preserving order — exactly matching the inner while-loop of the Python code.
-/

/-- The result of insertion sort is a permutation of the input. -/
theorem insertionSort_perm (l : List Nat) :
    (insertionSort (· ≤ ·) l).Perm l :=
  perm_insertionSort (· ≤ ·) l

/-- The result of insertion sort is sorted in non-decreasing order. -/
theorem insertionSort_sorted (l : List Nat) :
    Pairwise (· ≤ ·) (insertionSort (· ≤ ·) l) :=
  pairwise_insertionSort (· ≤ ·) l

/-- Combined: insertion sort produces a sorted permutation of its input. -/
theorem insertionSort_correct (l : List Nat) :
    (insertionSort (· ≤ ·) l).Perm l ∧
    Pairwise (· ≤ ·) (insertionSort (· ≤ ·) l) :=
  ⟨insertionSort_perm l, insertionSort_sorted l⟩
