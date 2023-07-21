{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        beam = pkgs.beam.packages.erlangR25;
        erlang = beam.erlang;
        elixir = beam.elixir_1_14;
        elixir_ls = beam.elixir_ls.override { inherit elixir; };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            git
            elixir_ls
            erlang
            elixir
          ];

          shellHook = ''
            # this allows mix to work on the local directory
            mkdir -p .state/mix .state/hex
            export MIX_HOME=$PWD/.state/mix
            export HEX_HOME=$PWD/.state/hex
            export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
            # TODO: not sure how to make hex available without installing it afterwards.
            mix local.hex --if-missing --force
            export LANG=en_US.UTF-8
            export ERL_AFLAGS="-kernel shell_history enabled"
          '';
        };
      });
}
