{
  description = "index of nixos users";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.utils.url = "github:numtide/flake-utils";
  inputs.lunarix.url = "github:skarlett/nixos-config";
  inputs.coggiebot.url = "github:skarlett/coggie-bot";
  inputs.jeffery.url = "github:QuantumCoded/nixos";

  outputs = {self, nixpkgs, utils, ...}@inputs:
    let
      pkgs = import nixpkgs { system="x86_64-linux"; };

      recursiveMerge = attrList:
        with pkgs.lib;
        let f = attrPath:
          zipAttrsWith (n: values:
            if tail values == []
              then head values
            else if all isList values
              then unique (concatLists values)
            else if all isAttrs values
              then f (attrPath ++ [n]) values
            else last values
          );
        in f [] attrList;

      # exclude inputs
      xinputs = (builtins.removeAttrs inputs
        ["override" "overrideDerivation" "self" "nixpkgs" "utils"]);

      output-list = map (c: c.outputs) (builtins.attrValues xinputs);
      outputs = recursiveMerge output-list;
      override-packages = (utils.lib.eachDefaultSystem (system: {
        # use lunarix's workflow-codegen
        # override self with our own outputs
        packages.mkci = inputs.lunarix.packages.${system}.mkci.override {
          self = outputs;
          inherit (inputs.utils.lib) eachDefaultSystem;
          inherit (inputs) nixpkgs;
        };
      }));
    in
      (recursiveMerge [ outputs override-packages ]);
}
