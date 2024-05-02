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

  };
}
