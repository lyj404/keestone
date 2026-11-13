# KeeStone compatibility patch

This directory contains the Dart library and license from kpasslib 1.1.2.
`KdbxTime._fromString` accepts empty KDBX 4 binary timestamps as absent and
rejects nonempty timestamps that do not decode to eight bytes. Remove the
override after an upstream release provides equivalent compatibility.
