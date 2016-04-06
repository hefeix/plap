# Probabilistic Learning and Programming #

> _Can we design programming languages containing machine learning primitives?_
> Can a new generation of computer programming languages directly support
> writing programs that learn? In many current machine learning applications,
> standard machine learning algorithms are integrated with hand-coded software
> into a final application program. Why not design a new computer programming
> language that supports writing programs in which some subroutines are
> hand-coded while others are specified as "to be learned." Such a programming
> language could allow the programmer to declare the inputs and outputs of each
> "to be learned" subroutine, then select a learning algorithm from the
> primitives provided by the programming language. Interesting new research
> issues arise here, such as designing programming language constructs for
> declaring what training experience should be given to each "to be learned"
> subroutine, when, and with what safeguards against arbitrary changes to
> program behavior. - Tom Mitchell,
> [The Discipline of Machine Learning](http://reports-archive.adm.cs.cmu.edu/anon/anon/ml/CMU-ML-06-108.pdf)

## Summary and Disclaimer ##

This is not a complete design for an
[artificial general intelligence](http://www.agiri.org/wiki/index.php?title=Artificial_General_Intelligence) (AGI). It _is_ a set of core components that, with future augmentation, will lead to a complete AGI design. The current system is essentially intended to function as a read-eval-print loop for an unusual Lisp dialect (Combo Lisp). This language is based on probabilistic semantics, and operates under assumptions of insufficient knowledge and resources. When no definite answer to a user's query is available, the Probabilistic Learning And Programming (Plap) System (comprising Combo Lisp and its attendant libraries as described herein) can return speculative answers synthesized through program induction, analogical mapping, and/or inference.

## Table of Contents ##

  1. [Premises](Premises.md)
  1. [Discussion](Discussion.md)
  1. [Core Language](CoreLanguage.md)
  1. [Insufficient Knowledge](InsufficientKnowledge.md)
  1. [Insufficient Resources](InsufficientResources.md)
  1. [Learning](Learning.md)
  1. [AnalogicalMapping Analogical Mapping
  1. [Inference](Inference.md)
  1. [Algorithms and Data Structures](AlgorithmsAndDataStructures.md)
  1. [Self-Reference and Self-Improvement](Self.md)
  1. [Implementation](Implementation.md)