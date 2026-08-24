class_name BareRefOtherFile extends RefCounted
# Reproduces the EXACT shape ADR-0002's mechanism five uses for
# AffinityReadResult, IF that class is placed in its own file per the
# Key Interfaces reading note ("affinity_read_result.gd"):
#   class AffinityReadResult extends RefCounted:
#       var rejection: ReadRejection = ReadRejection.NONE
# Here MyEnum is nested inside OuterHolder (a DIFFERENT file/class_name),
# and this file references it BARE (unqualified) -- exactly like the ADR's
# `var rejection: ReadRejection = ReadRejection.NONE` line does.

var rejection: MyEnum = MyEnum.A
