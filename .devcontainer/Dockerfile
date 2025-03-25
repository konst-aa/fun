FROM mcr.microsoft.com/devcontainers/base:ubuntu


RUN apt-get update
RUN apt-get install -y curl

# install nix
RUN bash -c "curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --init none --no-confirm"
