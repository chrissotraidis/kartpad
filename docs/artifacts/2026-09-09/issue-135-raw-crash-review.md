# A10X startup crash: supplied instruction evidence

Reviewed the [original report comment](https://github.com/chrissotraidis/kartpad/issues/135#issuecomment-5592114324)
in the 9 September 01:14 UTC maintenance cycle with an independent Medium worker.

The report identifies 0.4.0/build 15 and SIGILL in
RegisterStaticIndirectDispatchTable +36. Base64 atPC decodes to bytes
08 c1 bf 38: opcode 0x38bfc108, LDAPRB w8,[x8], independently disassembled using
Xcode llvm-objdump. The exception code matches. Apple clang targeting apple-a10
rejects the instruction because it requires RCpc. This directly supports the
unsupported-instruction startup diagnosis for the supplied report.

Decimal PC minus image base equals the reported offset: 4330467244 minus
4330242048 equals 225196. Correct hex values are PC0x1021dafac, base0x1021a4000,
offset0x36fac and function start0x36f88. The earlier paraphrase's hex conversions
were incorrect. The edited usedImages list contains five entries while frames
retain indices21/24; UUID is redacted, so exact binary identity is not verified.
Do not conflate this build15 report with the earlier build26 binary audit.

Published iPhone/iPad build29 uses LDARB at initializer +36. Existing release
audit records zero RCpc-family hits over17,528,634 decoded instructions and the
correct baseline flags for all six audited compiled targets. This review did
not repeat a full build or claim physical A10X acceptance. The reporter has been
asked to update in place with a backup and report whether the chooser opens.
No repeat raw-log request; issue remains open. Android/macOS/tvOS unaffected
by this report review.
