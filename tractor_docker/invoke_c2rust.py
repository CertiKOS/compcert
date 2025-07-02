#!/usr/bin/env python3
# Uses the Docker engine API to call the c2rust baseline

import argparse
import docker
import subprocess

from pathlib import Path


def invoke_translation(src: Path, out: Path, container_name):
    if out.exists():
        raise FileExistsError(f"{out} already exists (prior translation?)")
    if not (src / "CMakeLists.txt").exists():
        raise FileNotFoundError(f"No CMakeLists.txt found in {src}!")
    # get Docker to build a translation
    client = docker.from_env()
    image_src = "/tmp/src"
    image_dest = "/tmp/out"

    container = client.containers.run(
        container_name,
        [image_src, image_dest],
        volumes={
            str(src.resolve()): {"bind": image_src, "mode": "ro"},
            str(out.resolve()): {"bind": image_dest, "mode": "rw"},
        },
        working_dir="/usr/c2rust_execution",
        detach=True,
    )

    if container.wait()["StatusCode"] != 0:
        print("Error during translation:")
        print(container.logs().decode("utf-8"))

    container.remove()

    # generate Cargo lockfile for it
    subprocess.check_call(["cargo", "generate-lockfile"], cwd=out)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Invoke a conversion Docker image.")
    parser.add_argument("source", type=Path, help="The C project directory to convert")
    parser.add_argument("out", type=Path, help="The directory to place results in")

    parser.add_argument(
        "--container-name",
        type=str,
        help="The Docker image to run (defaults to c2rust baseline)",
        nargs="?",
        default="certic2rc",
    )

    args = parser.parse_args()
    invoke_translation(args.source, args.out, args.container_name)
