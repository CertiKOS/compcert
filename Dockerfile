FROM nixos/nix:latest

RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

WORKDIR /root/
COPY . .

RUN nix develop .#default -c true bash -c "./configure x86_64-linux && make"
# uncomment if crown compiler version is also useful
# RUN nix develop .#crown -c true

CMD ["/usr/bin/env", "bash"]
