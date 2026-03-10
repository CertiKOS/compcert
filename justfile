arch := env_var_or_default('ARCH', 'aarch64-macos')
num_cores := env_var_or_default('NUM_CORES', '8')

ensure_compcert:
  target="{{arch}}"; \
  expected_arch=""; \
  expected_system=""; \
  expected_bits=""; \
  case "$target" in \
    aarch64-linux|arm64-linux) \
      expected_arch="aarch64"; \
      expected_system="linux"; \
      expected_bits="64"; \
      ;; \
    aarch64-macos|aarch64-macosx|arm64-macos|arm64-macosx) \
      expected_arch="aarch64"; \
      expected_system="macos"; \
      expected_bits="64"; \
      ;; \
    x86_64-linux) \
      expected_arch="x86"; \
      expected_system="linux"; \
      expected_bits="64"; \
      ;; \
    x86_64-bsd) \
      expected_arch="x86"; \
      expected_system="bsd"; \
      expected_bits="64"; \
      ;; \
    x86_64-macos|x86_64-macosx) \
      expected_arch="x86"; \
      expected_system="macos"; \
      expected_bits="64"; \
      ;; \
    *) \
      echo "Unsupported ARCH target '$target' in justfile ensure_compcert."; \
      exit 1; \
      ;; \
  esac; \
  need_config=0; \
  if [ ! -f Makefile.config ]; then \
    need_config=1; \
  else \
    current_arch="$(sed -n 's/^ARCH=//p' Makefile.config)"; \
    current_system="$(sed -n 's/^SYSTEM=//p' Makefile.config)"; \
    current_bits="$(sed -n 's/^BITSIZE=//p' Makefile.config)"; \
    if [ "$current_arch" != "$expected_arch" ] || [ "$current_system" != "$expected_system" ] || [ "$current_bits" != "$expected_bits" ]; then \
      need_config=1; \
    fi; \
  fi; \
  if [ "$need_config" -eq 1 ]; then \
    ./configure "$target"; \
  fi; \
  if [ "$need_config" -eq 1 ] || [ ! -x ccomp ]; then \
    just build_ccomp_quick; \
  fi

# configure
build_compcert_full:
  ./configure {{arch}}
  just build_compcert_quick

build_ccomp_quick:
  dune build extraction/compcert/Driver.exe

# no configure
build_compcert_quick:
  make -j{{num_cores}}

compile_custom_test *name:
  pushd rust_tests && just clean && just build {{name}} && just compile {{name}} && popd

compile_custom_tests:
  pushd rust_tests && just clean && just compile_all && popd

test:
  just ensure_compcert
  pushd c2rust_testbed/working_tests && just test && popd
