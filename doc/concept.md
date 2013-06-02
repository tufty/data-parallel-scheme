# Concepts #

The idea is to write a data-parallel DSL in scheme.

Requirements -

Ypsilon Scheme (https://code.google.com/p/ypsilon/)

## Why? ##

The current way of programming, functional or otherwise, largely focusses on sequential execution of one task on one datum at any given instant in time.  This can be seen as a specialisation of a data-parallel model, where we execute one task on multiple data simultaneusly.

The single-instruction, single-datum, model no longer matches with the reality of available computing hardware.  With the generalisation of multi-core hardware, and, particularly, the ubiquitous availability of masively powerful, massively parallel, programmable GPUs on everything from mobile phones upwards, that model is looking increasingly dated and restrictive.

However, we are stuck in a conceptual straight-jacket; years of "sequentialising" inherently parallel algorithms means it's really hard to think about things in a parallel manner.  
