arch := env_var_or_default('ARCH', 'aarch64-macos')
num_cores := env_var_or_default('NUM_CORES', '8')

# configure
build_compcert_full:
  ./configure {{arch}}
  just build_quick

# no configure
build_compcert_quick:
  make -j{{num_cores}}

compile_custom_test *name:
  pushd rust_tests && just clean && just build {{name}} && just compile {{name}} && popd

compile_custom_tests:
  pushd rust_tests && just clean && just compile_all && popd


