{
  description = "index of nixos users";
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  inputs.nixos-generators = {
    url = "github:nix-community/nixos-generators";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  inputs.lunarix.url = "github:skarlett/nixos-config";
  inputs.jeffery.url = "github:QuantumCoded/nixos";

  outputs = {self, nixpkgs, ...}@inputs:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      lib = pkgs.lib;

      self.lib.debug = n: expr: lib.traceSeqN n expr expr;

      recursiveMerge = attrs: lib.fold lib.recursiveUpdate {} attrs;

      # exclude inputs
      xinputs = (builtins.removeAttrs inputs
        ["override" "overrideDerivation" "self" "nixpkgs" "nixos-generators"]);


      withSystem = f:
        lib.foldAttrs lib.mergeAttrs {}
        (map (s: lib.mapAttrs (_: v: {${s} = v;}) (f s))
          ["x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin"]);


      default-formats = [
        "docker" "amazon" "install-iso"
        "sd-aarch64-installer" "proxmox"
        "qcow" "vm" "vmware"
      ];

      genericGenerate = system: fmt: conf: inputs.nixos-generators.nixosGenerate {
        inherit system;
        inherit (conf._module.args) modules;
        inherit (conf._module) specialArgs;
        format = fmt;
      };

      partial-subpath = x:
        let
          ximports = i: lib.optionals ((builtins.typeOf i) == "set" && (builtins.hasAttr "imports" i))
            (map partial-subpath i.imports);

          file = s:
            lib.optional ((builtins.typeOf s) == "set" && (builtins.hasAttr "_file" s))
              s._file;

          path = p: lib.optional
            (builtins.typeOf p == "path" || builtins.typeOf p == "string") p;

          inp = if (lib.isList x) then x
                else [x];

        in
               map (y: ximports y) inp
            ++ map (y: file y) inp
            ++ map (y: path y) inp;

      # remove all paths static paths not found (broken configurations)
      subpaths' = conf-name: outputs.nixosConfigurations."${conf-name}".type.getSubModules;
      subpaths = conf-name:
        let
          submods = (subpaths' conf-name);
        in
          lib.lists.flatten (map partial-subpath submods);

      output-list = map (c: c.outputs) (builtins.attrValues xinputs);
      outputs = recursiveMerge output-list;

      export-tools = withSystem (system:
        let
          init-list = cfg-name: subpaths cfg-name;
          can-load = cfg-name: builtins.all (x: builtins.pathExists x) (init-list cfg-name);

          clean-conf = (builtins.removeAttrs outputs.nixosConfigurations
              ["override" "overrideDerivation"]
          );

          avail-confs = (builtins.filter can-load (builtins.attrNames clean-conf));

          genfield = fmt: cfg: (genericGenerate system fmt cfg);

          genset = fmt: name:
            lib.attrsets.nameValuePair "${name}-${fmt}" (genfield fmt outputs.nixosConfigurations.${name});

          okstub = name:
            (map (x: { ${x.name} = x.value;} )
              (map (x: x.value)
                (builtins.filter(x: x.success)
                  (map (fmt: builtins.tryEval (genset fmt name)) default-formats))));

          ok-all = (map (x: (okstub x)) avail-confs);
          stage1 = map (x: builtins.foldl' (s: c: s // c) {} x) ok-all;

          stage2 = map (x: builtins.foldl' (s: c: s // c) {} x) stage1;

        in {
          packages.subpath = subpaths;
          packages.subpath-raw = subpaths';
          packages.avail = avail-confs;
          packages.okstub = (map (x: (okstub x)) avail-confs);
          packages.stage1 = stage1;
        });

      override-packages = (withSystem (system: {
        # use lunarix's workflow-codegen
        # override self with our own outputs
        packages = {
          mkci = inputs.lunarix.packages.${system}.mkci.override {
            self = outputs;
          };
        };
      }));
    in
      (recursiveMerge [ outputs export-tools ]);
}
