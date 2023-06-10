{
  description = "index of nixos users";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.lunarix.url = "github:skarlett/nixos-config";
  inputs.jeffery.url = "github:QuantumCoded/nixos";

  outputs = {self, nixpkgs, ...}@inputs:
    let
      pkgs = import nixpkgs { system="x86_64-linux"; };
      xinputs = (builtins.removeAttrs inputs ["override" "overrideDerivation" "self" "nixpkgs"]);
      xoutputs = map (c: c.outputs) (builtins.attrValues xinputs);
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

    in
      (recursiveMerge xoutputs);
}
