# Docker setup

```sh
docker build -t certic2rc -f run_certic2rc.Dockerfile .
docker run -it certic2rc
```

# building test suite programs

Once inside the container, one can perform a C to Rust translation based on an input `compile_commands.json` or a list of input files.

```sh
docker run -v.:/. -it certic2rc:latest
## running test suite
just shell=bash edition=2021 build
```

# tractor test suite

TODOs:
- test runner docs
- tractor test integration + documentation
