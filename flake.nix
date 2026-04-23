{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    graph-browser.url = "github:lambdasistemi/graph-browser";
  };

  outputs =
    { nixpkgs, graph-browser, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          browser = graph-browser.packages.${system}.lib;
        in
        {
          default = pkgs.runCommand "cardano-governance-graph" { } ''
            mkdir -p $out
            cp ${browser}/index.html $out/
            cp ${browser}/index.js $out/

            # Copy data as writable; the importer loads each graphSource
            # listed in data/config.json directly, no concatenation needed.
            cp -r --no-preserve=mode ${./data} $out/data

            # Publish namespace document so the ontology IRI is dereferenceable
            mkdir -p $out/vocab
            cp ${./data/rdf/cardano.ontology.ttl} $out/vocab/cardano
          '';
        }
      );
    };
}
