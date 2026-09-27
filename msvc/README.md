# msvc

MSBuild projects for zlib and the external libraries ffmpeg links against, so that a
`--toolchain=msvc` build of ffmpeg (`build_ffmpeg_msvc.sh`) can enable the same
libraries the GCC build does. The prebuilt archives under `thirdparty/` are
MinGW `.a` files and cannot be linked by `link.exe`.

    libs/zlib           zlib, submodule, pinned at a release tag
    libs/dav1d          dav1d, submodule, pinned at a release tag
    libs/libxml2        libxml2, submodule
    libs/speex          speex, submodule
    libs/bzip2          bzip2, submodule
    libs/opencore-amr   opencore-amr, vendored (upstream has no git repository)

Each directory holds the project plus the generated headers that library's own
build system would otherwise produce (`config.h`, `vcs_version.h`, and so on).

`build_ffmpeg_msvc.sh` builds them when they are missing and enables the
matching `--enable-lib*` options, so an MSVC ffmpeg gets the same decoders as the
GCC one. It takes `clang` as an extra argument to compile ffmpeg with the clang
that Visual Studio installs (component "C++ Clang Compiler for Windows"), which
unlike cl can compile ffmpeg's inline assembly:

    sh build_ffmpeg_msvc.sh x64 release          cl
    sh build_ffmpeg_msvc.sh x64 release clang    clang

The projects are also in `LAVFilters.sln`, but are **not** built by the default
`Release` and `Debug` configurations, which keep using the prebuilt MinGW
archives. The `Release MSVC` configuration builds them from the IDE; they write
`bin_<platform>\lib` beside LAV's own libraries.

`common.props` is shared by all of them and imports `common\platform.props`,
so they follow the same toolset and SDK as the rest of LAV.
