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
- LLVM

  For:
  - Enormously flexible
  - Code generators for major GPUs (AMD R600, NVidia), work-in-progress for others (videocore, etc)
	and current CPU architectures (x86, ARM)
  - Optimisations for both "sequential" code and "parallel" (with http://polly.llvm.org)

  Against:
  - Continually "in flux", may depend on a specific version
  - LLVM IR is hard to write
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

Of the above, the most attractive to me is LLVM, closely followed by GLSL.  The rest are either
totally out (Windows only, NVidia only, ect) or would require me to buy new hardware to get them
to work (OpenCL).

So the current favoured approach is to generate LLVM IR and then harness the wonders of LLVM to
generate code.  If that doesn't pan out, I might have to fall back on OpenGL.

##Implementation issues##

###Structure###

It makes sense to have a multi-layer design, especially if it's possible I will have to fall
back on OpenGL or some other method.

###Efficiency###

Obviously, what we want to do is write code that's efficient.  This is a good resource to keep
in mind.

http://www.humus.name/Articles/Persson_LowLevelThinking.pdf

###Impedance mismatch # 1 - Numeric stack###

Scheme, of course, has a full numeric stack, with rationals, arbitrary length integers,
complex numbers, imprecise numbers and so on.  These provide enormous flexibility, but
come at a cost, not least of which is not having a necessarily fixed size for numbers.

LLVM uses something approaching the "C" approach.  We can have integers of (almost) arbitrary
size, the various IEEE floating point types, and that's your lot until you start deriving other
types.

###Impedance mismatch # 2 - Typing###

Scheme is, of course, a language that makes the most of (strong) dynamic typing. LLVM IR
is statically typed.  It's probably not
 feasible to take the "standard" scheme approach of tagging and dynamic typechecking -
it's likely that I will have to take a statically typed approach.  That sucks a bit.

https://github.com/norton/chibi-scheme/blob/master/lib/chibi/type-inference.scm might help

###How to evaluate code quality###

I'm probably gonna need a decompiler for the resulting binaries and some way of evaluating
"goodness".  Really not sure where to go with that.  Will ponder this later.

Apple's OpenGL implementation, at least on my iMac, doesn't provide `GL_ARB_get_program_binary`,
which might well have been invaluable.  I'm really not sure how to do this.

###How to deal with conditionals###

OpenGL really, really doesn't like conditionals.  Much of this is perhaps down to compiler
implementations, but conditionals are unpleasant, and can reuslt in all sorts of nastiness.
Might need to do some AST rewriting to "lift" conditionals and split cases into separate 
shaders, using split / calculate / merge stages.

Thus (begin (x) (y) (if w (z) 1)) might be split out into two separate shaders if it can 
be proved that w is not dependent on (x) and (y), thus (begin (x) (y) (z)) and (begin (x) (y) 1)

In this case, we need to somehow make one shader operate on one set of data, and another on 
another, and then fold them back together as a separate pass.  Depth buffering is probably the
neatest way to do this, but potentially means passing massive amounts of vertex data around.  
First cut render to depth buffer? 

Given the following:

    (lambda (x)  
      (+ x (if (> 1 x)  
               (f x)  
		       (g x))))

We can lift the conditional to provide

    (lambda (x)  
      (if (> 1 x)  
          (+ 1 (f x))  
    	  (+ 1 (g x))))

If x is an array data type, this provides the opportunity to break the computation down into
4 sequential steps as follows:

    (lambda (x)  
      (let ([x1 (select (> 1 x) #t #f)]  
            [x2 (+ 1 (f x))]  
    		[x3 (+ 1 (g x))])  
        (select x1 x2 x3)))
    
Obviously the second and third steps might, and probably should, be optimised to conditionalise
on `x1`, (in OpenGL, probably using a depth or stencil buffer approach), although this may impose more cost than it reduces, but the fundamental structure is evident

- Using a parallel selection across the input data, segment into subsets for all conditionals
  that don't trivially reduce to a selection between 2 known values
  
- For each subset (2 in the above case, but conditional lifting could result in many more)
  carry out the relevant, non-conditional, computation

- Reuse the segmentation data created in the first step to recombine the results.

A more idiomatic way of doing things might be to use code that perhaps looks something like this:

    (lambda (x)
	  (select-parmap-merge (if (> 1 x) 0 1)
	    [0 => (+ 1 (f x))]
		[1 => (+ 1 (g x))]))

Where `select-parmap-merge` deals with the boilerplate of generating programs for the various cases,
generating the selection data, and merging the results at the end.  This suggests a syntax something
like

    (lambda (x)
	  (parmap (+ 1 x)))

For "trivial" parallel mappings across datasets (and, potentially, dataset creation)

### What of reductions? ###

Reductions are conceptually relatively boring, involving repeated application of a reduction function
on 4 elements to carry out power-of-two reductions in the style of mipmapping.

	(lambda (x)
	  (reduce Fn x))

There are, however, a couple of twists to this.

Firstly, reductions are only "boring" if we're dealing with datasets loaded into the entirety of a 
texture.  And, although textures don't *have* to be power-of-two, performance is (potentially 
enormously) improved when they are.

Why?

Consider the following 4x4 texture (yeah, in reality a 4x4 texture is probably too small to 
parallelise efficiently, but my keyboard needs a break) where the `.` in cells [3,4] & [4,4] 
indicates "not used".

	 +-+-+-+-+
	 |1|2|3|4|
	 +-+-+-+-+
	 |5|6|7|8|
	 +-+-+-+-+
	 |9|8|7|6|
	 +-+-+-+-+
	 |5|4|.|.|
	 +-+-+-+-+

Now, for a simple array->array parallel map, for example our hypothetical

     (parmap (+ 1 x))

we can either process the "unused" cells and take the minor performance hit, or be a bit clever
and take steps to simply not process them. In any case, downstream code won't be using anything
in those cells, so we're safe.

Now consider a simple reduction, for example averaging.  If we take a 4x4 mipmap approach, we would 
expect the following output from our first recursion:

       +---+---+
       |3.5|5.5|
       +---+---+
       |6.5|6.5|
       +---+---+

Now, each of those cells is calculated using a single "instruction" (in reality, a shader program)
and the lower right hand corner contains two undefined values.  Thus the shader program needs to 
allow for the fact that some cells may be empty, somehow detect that status, and adapt its 
processing to that fact.  Thus, in the bottom right hand corner, it should only take into
account the values at [3,3] and [3,4], and then divide its result by 2 rather than 4.  This puts
a significant amount of additional processing into the (limited) space allowed for a shader program
and will degrade performance.

An alternate approach would be to split the texture into that which fits into a single power-of-two
texture (and can thus be efficiently parallelised) and "the rest" to be handled on the scalar side.
We then further split the rest into power-of-two subtextures until we can no longer efficiently
process, but at some point we must end up with a certainamount to be carried out in a scalar manner.
For the above example, we could handle all but the bottom-right quadrant in parallel (rather than
drawing a single quad covering the enire "computation surface", we would draw 3 quads covering the
relevant quadrants) and handle the remaining cells in a scalar fashion.  The second recursion
cannot be parallelised, so must be carried out in a scalar fashion.  

This approach is feasible, and results in a minimal scalar load, but requires non-naive texture 
loading in order to ensure minimal "unloaded" subtextures.  The obvious solution to this is to
use a morton curve for indexing the entries.

The next "hic" comes from the fact that a parallelised reduction, coded in a naive manner, may
require a "first iteration" program and a "second iteration" program.

Consider, for example

	(any? (< x 3))

If we take this naively, we would need to make a first reduction pass comparing the 4  relevant
elements to 3, and setting the output values to `#t` or `#f` as necessary, and the second and
subsequent passes reducing using `(any? x)`.  This, in fact gives us our probable solution, via
an expansion to

	(any? (parmap (select (< x 3) #t #f)))

In other words, perform a parallel mapping pass to map input values to the correct type for
the reduction pass.

And then there's another 'hic'.  If we go back to the first example, averaging values in an
array, the attentive reader will have noticed that we *do not get a correct value* via
mipmapping unless we are reducing across the entirety of the array.  So if the 2 unfilled
cells contained 3 and 2,

	(/ (+ 1 2 3 4 5 6 7 8 9 8 7 6 5 4 3 2) 16) ;; => 5
	(/ (+ (/ (+ 1 2 5 6) 4)
	      (/ (+ 3 4 7 8) 4)
	      (/ (+ 9 8 5 4) 4)
	      (/ (+ 7 6 3 2) 4)) 4)                ;; => 5

but

	(/ (+ 1 2 3 4 5 6 7 8 9 8 7 6 5 4) 14)     ;; => 75/14
	(/ (+ (/ (+ 1 2 5 6) 4)
	      (/ (+ 3 4 7 8) 4)
	      (/ (+ 9 8 5 4) 4)
	      (/ (+ 7 6) 2)) 4)                    ;; => 11/2

Oh dear.

For averaging, the solution would be to treat the two unused values as zero, and divide by 16 / 4
as necessary.  But that's not generalisable.  And why is that?  It's because averaging is not
associative.

_Reductions need to be associative_

So we need to work out what's associative, and what's not.
