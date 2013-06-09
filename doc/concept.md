# Concepts #

The idea is to write a data-parallel DSL in scheme, and perhaps go as far a scheme->data-parallel DSL
compiler and runtime.

Requirements -

Ypsilon Scheme (https://code.google.com/p/ypsilon/)

## Why? ##

The current way of programming, functional or otherwise, largely focusses on sequential execution of 
one task on one datum at any given instant in time.  This can be seen as a specialisation of a 
data-parallel model, where we execute one task on multiple data simultaneusly.

The single-instruction, single-datum, model no longer matches with the reality of available 
computing hardware.  With the generalisation of multi-core hardware, and, particularly, the 
ubiquitous availability of masively powerful, massively parallel, programmable GPUs on everything 
from mobile phones upwards, that model is looking increasingly dated and restrictive.  Yeah, I 
come from the generation that looked with awe on Hillis' Connection Machine, that read up everything 
available regarding the Transputer, who couldn't wait for the future, when parallel computing would be 
commonplace.  Well, I can now, for the price of a round of beers, buy a multi-core ARM-based board 
with a massively powerful vector processor hanging off it; *that future is now*.

However, we are stuck in a conceptual straight-jacket; years of "sequentialising" inherently 
parallel algorithms means it's really hard to think about things in a parallel manner.  
As my friend said yesterday,

> I blame Knuth

Even pure functional programming, which is the obvious choice for massively parallel tasks, gets tied up
in the "sequential" knot.  We optimise functions to match the sequential mindset, rather than
decomposing what are, fundamentally, data-parallel tasks and using the hardware we have at our
disposal to its best.  It's not helped by the fact that, when trying to actually use data-parallel
hardware, functional languages are largely restricted to using foreign function interfaces, to
using fundamentally imperative layers over the hardware.

##The problems##

The first question we have to ask is "what tools should we use?".

The choice of "host" language is relatively simple - I use Ypsilon scheme on a regular basis, and it has
a relatively simple FFI interface.  Yeah, I've tried most of the others, but I keep coming back to
Ypsilon.  It's an arbitrary choice, but, after all, it's mine.

The next question is the "target" platform.  Not in terms of hardware, but in terms of the software
platform.  There's a few choices:

- OpenCL

  For:
  - Flexible
  - Standardised
  - Implements most of the "C" language
  - Uses GPU & CPU compute targets transparently
  
  Against:
  - Not widely available
  - Only suports high-end GPUs - "lesser" platforms have to make do with CPU-only
- CUDA

  For:
  - Flexible
  - Well documented with much example code
  
  Against:
  - GPU only
  - Vendor-specific, I don't have an NVidia GPU :)
- OpenGL Shader Language

  For:
  - Standardised
  - Widely available, with software emulation available on unsupported platforms
  
  Against:
  - GPU only
  - Not a general purpose compute platform - aimed at graphics usage
  - Restricted subset of operators.
- High Level Shader Language (HLSL)

  For:
  - Well documented, much example code
  
  Against
  - GPU only
  - Vendor-specific, I don't do MS
- Brook+

  For:
  - Already does a lot of what we want.
  
  Against:
  - Not sure.  Scheme->Brook?  dunno.
- GPU specific assembler

  For:
  - Allows access to all functionality of the GPU
  
  Against:
  - Entirely platform specific
  - Extremely hard to get right if you're not an expert
  - Low level documentation is rare and sketchy

Surprisingly perhaps, my choice here is OpenGL Shaders.  OpenCL is attractive, but it would mean
upgrading my machine to get full usage (it's a 5 year old iMac), and it would be too easy to take
the "easy" way out, repurposing a scheme->c compiler.  CUDA isn't supported on my hardware, so
that's out.

So.  GLSL as GPU compute platform, but with the following overall goals:

- GPU *and* CPU compute.  Don't want to leave those transistors idling, do we?
- Layered design.  Want to be able to "swap out" GLSL and "swap in" something else if needed
  (Raspberry Pi GPU-specific assembler, anyone?)

Now, GLSL is *not* a general-purpose compute platform, although it can be butchered to
be one if you're crazy enough.  And yes, I think I'm crazy enough.

##Implementation issues##

###Efficiency###

Obviously, what we want to do is write code that's efficient.  This is a good resource to keep
in mind.

http://www.humus.name/Articles/Persson_LowLevelThinking.pdf

###Numeric stack###

Scheme, of course, has a full numeric stack, with rationals, arbitrary length integers,
complex numbers, imprecise numbers and so on.  These provide enormous flexibility, but
come at a cost, not least of which is not having a necessarily fixed size for numbers.

OpenGL uses the "C" approach. Fixed-range integers, fixed-size imprecise numbers (floats)
and booleans.  That's it.

How to deal with this impedance mismatch?

