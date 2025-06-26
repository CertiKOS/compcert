# Docker setup

```
docker build -t certic2rc -f Dockerfile .
docker run -it certic2rc
```

# running programs

Once inside the container, once can run the internal test suite:

```
cd c2rust_testbed/working_tests
just edition=2021 test
```

Additionally, entire C projects may be translated by cloning the builder:

```
git clone git@github.com:DieracDelta/rust_benchmarks.git crown_benches
cd rust_benchmarks/runner
cargo run --release -- -c /root/crown_benches/benchmarks/tests.json -r /home/jrestivo/dev/crown_benches/benchmarks/
```


Results from the translation will end up in the corresponding folders under `crown_benches/benchmarks/*`. The corresponding folder name will typically be listed in `crown_benches/tests.json` under `rust_run_cmd` for each test.

