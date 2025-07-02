# # https://hub.docker.com/_/rust
# # bookworm: Debian 12
# FROM rust:bookworm
#
# # prepare dependencies for c2rust
# RUN apt-get update && apt-get install -y \
#     build-essential \
#     llvm \
#     clang \
#     libclang-dev \
#     cmake \
#     libssl-dev \
#     pkg-config \
#     python3 \
#     git
# # Specify Rust toolchain as pre-kickoff stable release
# RUN rustup default 1.87.0
#
# # Needs --locked to avoid updating dependencies with breaking changes
# # For instance, proc_macro2 is locked to 1.0.86
# # but breaks when updated to 1.0.94
# # 0.20.0 has been released and is on cargo as of March 2025
# RUN cargo install \
#     --version 0.20.0 \
#     --locked \
#     c2rust
#
# # move to a new folder and prepare the entrypoint executable
# WORKDIR /usr/c2rust_execution
# COPY get_target.py ./
# COPY c2rust_commands.sh ./
# RUN ["chmod", "+x", "c2rust_commands.sh"]
#
# # c2rust_commands.sh is an example implementation using c2rust
# # All translation containers should define their own ENTRYPOINT,
# # an executable taking two arguments:
# # a source directory and an output directory.
# # You may modify this Dockerfile and script or implement your own.
# ENTRYPOINT [ "/usr/c2rust_execution/c2rust_commands.sh" ]
#

FROM nixos/nix:latest AS build
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
WORKDIR /root/
COPY ./flake.nix .

# cache the stuff in a separate layer so we only ever need to do this once
RUN nix develop .#staticShell -c true

COPY . .

RUN nix develop .#staticShell -c ./configure x86_64-linux
RUN nix develop .#staticShell -c dune build _build/x86_64


FROM alpine:latest AS runtime

WORKDIR /usr/certic2rc_tools
COPY --from=build /root/tractor_docker/get_target.py /root/tractor_docker/c2rust_commands.sh /root/_build/x86_64/compcert.ini  /root/_build/install/x86_64/bin/ccomp ./

# todo tractor script compatibility
# RUN ["chmod", "+x", "c2rust_commands.sh"]
WORKDIR /usr/c2rust_execution
# COPY . /usr/c2rust_execution
ENV PATH=/usr/certic2rc_tools/:$PATH
ENV COMPCERT_CONFIG=/usr/certic2rc_tools/compcert.ini
RUN apk update
RUN apk add build-base just bash

CMD ["/bin/sh"]
