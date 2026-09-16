# Third-Party Notices

EnshroudedSaveExplorer includes or links against third-party components.

These components are not covered by the EnshroudedSaveExplorer 0BSD license and remain subject to their own respective terms.

## Zstandard (Zstd)

EnshroudedSaveExplorer statically links against the Zstandard compression library.

Project:

https://github.com/facebook/zstd

Zstandard is distributed under a dual BSD / GPLv2 license. EnshroudedSaveExplorer uses it under the BSD license option.

Copyright (c) Meta Platforms, Inc. and affiliates.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the applicable Zstandard BSD license terms are respected.

The complete upstream license can be found in the Zstandard source distribution:

https://github.com/facebook/zstd/blob/dev/LICENSE

## MinGW-w64 runtime import libraries

The Windows build includes MinGW-w64 import libraries used to resolve C runtime functions required by the statically linked Zstandard library.

Included files:

* `src/third_party/mingw/win64/libucrt.a`
* `src/third_party/mingw/win64/libmsvcrt.a`

Project:

https://www.mingw-w64.org/

https://github.com/mingw-w64/mingw-w64

Relevant parts of the MinGW-w64 runtime are distributed as public-domain material and include a no-warranty disclaimer.

Refer to the upstream MinGW-w64 distribution for the precise licensing terms applicable to individual files and generated libraries.

## Free Pascal and Lazarus

EnshroudedSaveExplorer is built using Free Pascal and Lazarus.

Free Pascal and Lazarus are development tools and libraries distributed under their own licenses.

Their inclusion as build dependencies does not change the license of the original EnshroudedSaveExplorer source code.

Project websites:

https://www.freepascal.org/

https://www.lazarus-ide.org/
