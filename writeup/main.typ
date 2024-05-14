#import "@preview/charged-ieee:0.1.0": ieee

#show: ieee.with(
  title: [528 Final Report],
  abstract: [
    Rust is a modern, memory safe language, and C2Rust is an industry tool that transpiles C code into Rust code.
    The intended usecase of C2Rust is to move legacy code bases so that these code bases may be maintained and extended using Rust.
    However, C2Rust makes no guarantees about the resulting Rust code.
    CompCert is a C compiler that does make guarantees of semantic preservation when compiling C to dialects of assembly.
    In this report, we discuss repurposing CompCert to compile C code to Rust code similarly to C2Rust in a fashion that guarantees semantic preservation.
  ],
  authors: (
    (
      name: "Justin Restivo",
      email: "justin.restivo@yale.edu"
    ),
  ),
  bibliography: bibliography("refs.bib"),
)

= Introduction and Prior Work

We motivate our problem by introducing Rust and prior work on compiling C to Rust and Compcert.

== Rust

Rust is a relatively new (circa 2014) modern systems programming language that claims to be memory safe. Rust achieves memory safety by introducing an "ownership" model. Each variable and expression is "owned" by a thread for a period of time (denoted lifetime), then is deallocated. Each owned variable must either be marked as mutable or immutable. Immutable variables may have pointers shared across function and thread boundaries. Mutable variables may not. This rule, combined with runtime checks on memory accesses on data structures such as arrays provides memory safety.

These rules are too restrictive for many systems use cases. For example, in kernel code, writing to MMIO (memory-mapped input output) requires writing directly to an hard-coded address. This goes against Rust's rules, because the address could be invalid at runtime and so Rust prevents creation of a pointer from an address. Another example is the limitation of the type system on data structures such as linked lists. Linked lists are difficult to construct because the lifetime restictions of the type system make inserting nodes that live for less time than the root node impossible  @linkedlists .

Rust distinguishes between "safe" and "unsafe" Rust code. Safe code must adhere to the aforementioned rules, and unsafe code provides much freedom and is closer to C semantics. The mutable pointer rule is discarded through the use of other pointer types (`const *` and `mut *`). Lifetimes may live for the length of the entire program @unboundedlifetimes . As a result, these portions of code lose the memory safety aspect of Rust. Furthermore many primitives typically used in safe Rust are implemented in unsafe Rust, such as the standard library. The guarantee Rust then makes, which falls short of memory safety, is that undefined behaviour may only occurr in code marked as unsafe.

== C2Rust

C2Rust is a tool, written in Rust, that compiles C99 code to a combination of safe and unsafe Rust. It initially converts C99 to unsafe Rust, then applies code transformation passes to convert unnecessarily unsafe Rust to safe Rust. It makes migration of legacy C code to Rust straightforward. It is preferable to the alternative of using a foreign function interface (standardly performed with bindgen @bindgen ) because it makes the developer workflow simpler and enables more complete usage use of Rust code analysis tools like cargo careful (which runs an undefined behaviour at runtime check, Miri, under the hood).

C2Rust, however, comes with incomplete correectness guarantees:

- C2Rust relies on a two year old version of the nightly Rust compiler (e.g. using unstable features) and also targets (in compiled code) the same bleeding edge rust with unstable features. Several unstable features are needed to support C99 variadic functions, keywords like `thread_local` , and atomic intrinsics @trackingIssue. It is generally standard in industry code to require the consistency of a stable release Rust compiler. Thus, a choice of targeting nightly Rust hurts usability.
- As of the time of this report, there are 44 open bugs @c2rustBugs. Many seem to be syntax errors and unhandled edge cases.
- Correctness guarantees come empirically from tests and successful compilation of C codebases. This may not be sufficient for many use cases in safety critical systems where correctness is paramount.
- C2Rust depends on libclang for macro expansion and AST generation. This significantly expand the trusted codebase.

=== Ferrocene Specification

Ferrous Systems introduces a C-like (e.g. axiomatic) specification for Rust. This specification explicitly lists what is considered undefined behaviour. This is a major improvement over the status quo which is an implementation defined specification @ub . Ferrous Systems also provides a compiler that is claimed to meet this specification. @ferrocenespec

// === RustBelt
//
// === Formal Semantics
//
// ==== FormalLand
//
// ==== Miri/jungs other work

== CompCert

CompCert is a compiler for a dialect of C, Compcert C, that is close to the C99 standard. Compcert compilation from Compcert C to assembly guarantees semantic preservation. That is, Compcert guarantees compiled code "improves upon" the allowed behaviour of the input program, where "improve upon" means converting a runtime error into "a defined behaviour" @compcert . More formally, this is denoted semantic preservation.

= Design and Implementation

The high level idea for this project is to translate a macro-expanded C syntax into a subset of Rust syntax (denoted RustLight), then prove semenatic preservation with Coq. The use would then be to extract Rust syntax and feed it into a compiler (choices include Rustc, Ferrous System's compiler, or GCC).

There are four main choices for the IR to translate into RustLight: CompCert C, CLight, C\#Minor and CMinor. Compcert C naturally match C semantics. However, Compcert C (and its semantics), are complex. Clight side steps much of C's complexity while remaining relatively high level. CSharpMinor and C\#Minor become syntactically less near C99 and closer to assembly. Ultimately, I chose Clight as the language to translate into RustLight, as most of the constructs paralleled a subset of Rust's.

The remainder of the design of this project is composed of the following steps:

- Design a RustLight IR to represent programs with Rust. Equivalent to the Clight `program` type.

- Define an small step operational semantics for RustLight programs.

- Define a translation from CLight to RustLight. Analagous to `frontend/cshmgen.v`.

- Prove the semantics match. Analagous to `frontend/cshmgenproof.v`.

- Show that the resulting Rust code is well-typed. This would somewhat mirror `frontend/CTyping.v` but with lifetime reasoning.

- Write a pretty printer similar to `PrintClight.ml` and set up extraction.

- Print the generated Rust code from Compcert via a flag (similar to the other pretty-printed IRs).

== RustLight Design

We wish to model the RustLight IR and semantics after a pre-existing IR of Rust such that we may rely on implementation behaviour of that IR (paired with the semantics of the ferrocene spec). The various IRs and their semantics are informally defined within the primary Rust compiler frontend @rustc (which is fed through llvm). This frontend has three IRs @rust-dev beyond the parsed AST. A HIR (high-level IR), a THIR (typed high level IR), and a MIR (middle level IR).

- The HIR is represented as a macro-expanded AST. While not stable (or exposed externally) this makes it a good choice for RustLight due to being high level and allowing for explicit struct/union definitions.

- The HLIR, while lower level and more explicit, represents solely executable code. This presents a problem if we were to ever compile libraries and wanted to expose structs. Translation from a CLight `program` would be doable, but more complicated. The HLIR is also not exposed externally as stable.

- The MIR also only represents executable code. There is an effort to expose a stable API for other static analysis passes.

We propose an IR that is HIR-inspired (and extractable). We do this for several reasons: the HIR is closest to Rust syntax, so the output RustLight code may be maintained and used in real Rust projects once extracted. This should ensure the practicality remains similar to that of C2Rust.

A naive approach (my first attempt) was to write a IR that closely resembles Clight but to not reuse any infrastructure such as the types. Upon implementing this, there were only a couple of small differences at the C type level, primarily included the addition of lifetimes. Furthermore, on the expression level, some control flow constructs did not have obvious parallels.

My second attempt at an IR reused the types from Ctypes. I claim that this IR can match the semantics of a small subset of unsafe Rust. The majority of the focus thus far on this project has been on identifying the smallest subset of *unsafe only* Rust that can be used to represent all C operations.

== RustLight Implementation


=== Implementation Consideration: Lifetimes

In the Rustc HIR, lifetimes are part of types, because even though in unsafe Rust there exist pointer types that may violate the single mutable reference or many immutable references rule, those types still must have a lifetime. In the Rustc HIR, lifetimes are first converted to MIR then checked. However, the safe code lifetime rules are more restrictive (e.g. reasoning with pointers and lack of transmute), so it should be simpler to analyze lifetimes if all the code is unsafe. To handle this problem, C2Rust implemented its own borrow checker to check that the lifetime rules Rust enforces are matched by its transpiled code. This lifetime analysis will need to be done for RustLight.

As an initial straw-man, we introduce a `lifetime` time that may either be unbounded (e.g. living the entire life of the program. Slightly more encompassing than `'static`). The `Bounded` constructor takes as an argument the set of statements (identified by unique identifier, `int`).

```coq
Inductive lifetime : Type :=
  | Unbounded
  | Bounded: Set int -> lifetime.
```

We then define expressions similarly to `CLight`, except augmented with a lifetime in each constructor:

```coq
Inductive expr : Type :=
  | Econst_int: int -> type -> lifetime -> expr
  | Econst_float: float -> type -> lifetime -> expr
  | Econst_single: float32 -> type -> lifetime -> expr
  | Econst_long: int64 -> type -> lifetime -> expr
  | Evar: ident -> type -> lifetime -> expr
  | Etempvar: ident -> type -> lifetime -> expr
  | Ederef: expr -> type -> lifetime -> expr
  | Eaddrof: expr -> type -> lifetime -> expr
  | Eunop: unary_operation -> expr -> type -> lifetime -> expr
  | Ebinop: binary_operation -> expr -> expr -> type -> lifetime -> expr
  | Ecast: expr -> type -> lifetime -> expr
  | Efield: expr -> ident -> type -> lifetime
  | Esizeof: type -> type -> lifetime -> expr
  | Ealignof: type -> type -> lifetime -> expr.
```

Then, for statements, we remain very similar to CLight's syntax:

```coq
Inductive statement : Type :=
  | Sskip : statement
  | Sassign : expr -> expr -> statement
  | Sset : ident -> expr -> statement
  | Scall: option ident -> expr -> list expr -> statement
  | Sbuiltin: option ident -> external_function -> typelist -> list expr -> statement
  | Ssequence : statement -> statement -> statement
  | Sifthenelse : expr  -> statement -> statement -> statement
  | Sloop: statement -> statement -> statement
  | Sbreak : statement
  | Scontinue : statement
  | Sreturn : option expr -> statement
  | Smatch : expr -> match_stmt  -> statement
with match_stmt : Type :=
  | LSunderscore: statement
  | LScons: Z -> statement -> match_stmt -> match_stmt.

```

Note the omission of `goto`, `switch` and `label` and the addition of a `match` statement. These do not have analogues in the HIR.

The `program` type also remains the same and is analogous to CLight except with Rust statements and expressions.

Having defined the IR, the rest of effort towards this project was targeted at replicating CLight's definitions and helper functions, up to the program level. The majority of time was spent reading Compcert's code and trying to understand the overarching structure enough to find (at a high level) where the appropriate parts were to make modifications.

== On-Paper Translation

=== Lifetimes

For lifetimes, a strawman approach (that I have yet to implement) could be to take the union of the paths from the declarative to use and set that as the used set. There's also needed infrastructure to obtain unique integer identifiers for each statement to obtain this map. For calculating lifetimes, I could initialize all lifetimes to be unbounded and make no guarantees about how long each variable lives. Then, in a secondary pass, union together all def-use chains spawned from the expression. Note: this is orthogonal to type checking, which ensures that lifetimes don't violate certain rules such as use after relinquishing ownership.

The generated syntax for lifetimes can be explicitly defined at the function call boundary by adding in a named lifetimes @unboundedlifetimes .

=== Casts

Casts are also nontrivial. Casting between primitives, and between mutable pointers (for example `int*` to `float*`) may be done explicitly in rust using `as` syntax. However, casts between structs and unions will need to call the compiler intrinsic `std::mem::transmute`. We run into some difficulty here as `transmute` is a compiler intrinsic (builtin function) and thereby an `external_function` and of type `statement`. As primarily a straw-man we avoid the issue by pushing casting to extraction. A cast between structs or unions will invoke transmute, but this will only be evidenced in the pretty printing, since the underlying semantics match that of C.

=== Control Flow

- For switch statements, we use rust's match statement on an integer expression.
- For gotos referencing labels, we can mimick C2Rust's approach of translating the control flow to a combination loops and conditionals.
- We simply omit unreferenced labels as purely a syntactic construct.

== Future Work

The next steps (as outlined in the overview of section 2) are to define operational semantics for RustLight and to formalize these on-paper intuitions in in Coq. We choose to use the Ferrocene specification off which to base semantics. More future work includes defining further passes that lift unsafe Rust to a combination of unsafe and safe Rust.

= Conclusion

C2Rust is a great industry tool for compiling C to Rust. However, it lacks formalisation in its output, and relies on a test suite for correctness. We present the ideas behind a compiler from C to Rust implemented within Comcpert to provide semantic preservation, and the discuss initial steps taken towards its implementation.
