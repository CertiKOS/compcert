#!/bin/bash
# c2rust_commands.sh <project src directory> <output directory>
# Example implementing source translation by using c2rust
mkdir build
pushd build

# include CMake file API query to extract target name
mkdir -p .cmake/api/v1/query
touch .cmake/api/v1/query/codemodel-v2
cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 $1/CMakeLists.txt

target_name=$(python3 /usr/c2rust_execution/get_target.py . name)
target_type=$(python3 /usr/c2rust_execution/get_target.py . type)

ccomp -fpacked-structs -fstruct-passing -funstructured-switch -std=c99 -drustlight -lm -rust-edition {{edition}} -dcompile_command_location compile_commands.json -o /tmp/$target_name

# emits Cargo.toml in build directory
# if [[ "$target_type" == "EXECUTABLE" ]]; then
    # # for binaries; assumes main.c has entry for program
    # c2rust transpile --binary main -o /tmp/$target_name compile_commands.json
    # # preserve name of executable for cargo
    # sed -i "s/name = \"main\"/name = \"$target_name\"/" /tmp/$target_name/Cargo.toml
# else
    # for libraries
    # uses $target_name for output folder
    # so c2rust preserves name of library for cargo
    # c2rust transpile --emit-build-files -o /tmp/$target_name compile_commands.json
# fi

#
mv /tmp/$target_name/* $2