# Candidate build image for PINI (P0-10 dry run; ADR-0004).
# RHEL 8-compatible base, so binaries keep upstream's glibc 2.28 floor.
# Deviation from upstream (Clang 20.1): AlmaLinux 8 ships Clang 21.1.8 only.
FROM almalinux:8

RUN dnf -y install dnf-plugins-core \
 && dnf -y install \
      clang lld llvm \
      gcc-toolset-14-gcc-c++ gcc-toolset-14-libatomic-devel \
      python3.12 rust cargo \
      make which xz tar gzip diffutils findutils file procps-ng \
 && dnf clean all \
 && alternatives --set python3 /usr/bin/python3.12

ENV CC=clang CXX=clang++
