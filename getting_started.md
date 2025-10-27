= Running tests

```bash
nix develop -c "cd c2rust_testbed/working_tests && just test"
```

= Running crown benchmarks

```bash
nix develop
git clone git@github.com:DieracDelta/rust_benchmarks.git
export BM_PATH=$PWD/rust_benchmarks/benchmarks
cd rust_benchmarks/runner
cargo run --release -- -c $BM_PATH/tests.json -r $BM_PATH --excluded urlparser,ht_perfget,ht_perflbh,lodepng_decode
```
