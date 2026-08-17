cmake_minimum_required(VERSION 3.16)
project(NeroClang VERSION 1.0.0 LANGUAGES NONE)

# Nero is built in-tree with the pinned LLVM monorepo; this top-level project
# deliberately never substitutes a host clang for the compiler artifacts.
add_custom_target(nero
  COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/build-nero.sh" --all
  USES_TERMINAL)

