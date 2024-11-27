{
  description = "konstantin astafurov's mini-projects";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: 
  let pkgs = nixpkgs.legacyPackages.x86_64-linux; in {

    packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;

    packages.x86_64-linux.default = self.packages.x86_64-linux.hello;


    devShells.x86_64-linux.autodiff-chicken = pkgs.mkShell {
      name = "autodiff-chicken";
      buildInputs = with pkgs.chickenPackages.chickenEggs; [ 
        pkgs.chicken
        breadline
      ];
    };

    devShells.x86_64-linux.mips-c-vm = pkgs.mkShell {
      name = "mips-c-vm";
      buildInputs = with pkgs.chickenPackages.chickenEggs; [
        pkgs.chicken
        r7rs
        breadline
        pkgs.gnumake
        pkgs.SDL2
        pkgs.pkg-config
        pkgs.gcc
        pkgs.mars-mips
        # pkgs.chibi
      ];
    };
  };
}
