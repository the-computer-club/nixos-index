{
  description = "index of nixos users";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.lunarix.url = "github:skarlett/nixos-config";
  inputs.jeffery.url = "github:QuantumCoded/nixos";

  outputs = {self, nixpkgs, ...}@inputs:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      lib = pkgs.lib;

      recursiveMerge = attrs: lib.fold lib.recursiveUpdate {} attrs;

      withSystem = f:
        lib.foldAttrs lib.mergeAttrs {}
        (map (s: lib.mapAttrs (_: v: {${s} = v;}) (f s))
          ["x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin"]);

      # exclude inputs
      xinputs = (builtins.removeAttrs inputs
        ["override" "overrideDerivation" "self" "nixpkgs" "utils"]);

      output-list = map (c: c.outputs) (builtins.attrValues xinputs);
      outputs = recursiveMerge output-list;
      override-packages = (withSystem (system: {
        # use lunarix's workflow-codegen
        # override self with our own outputs
        packages.mkci = inputs.lunarix.packages.${system}.mkci.override {
          self = outputs;
        };
      }));
    in
      (recursiveMerge [ outputs override-packages ]);
}
