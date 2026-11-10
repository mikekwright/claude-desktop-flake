{
  description = "Claude Desktop for Linux and macOS, sourced from numtide/llm-agents.nix";

  # nixConfig = {
  #   extra-substituters = [ "https://cache.numtide.com" ];
  #   extra-trusted-public-keys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
  # };

  inputs.llm-agents.url = "github:numtide/llm-agents.nix";

  outputs =
    { self, llm-agents, ... }:
    let
      nixpkgs = llm-agents.inputs.nixpkgs;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      forAllSystems =
        f:
        builtins.listToAttrs (
          map (system: {
            name = system;
            value = f system;
          }) systems
        );

      packageFor = system: llm-agents.packages.${system}.claude-desktop;

      binaryCache = {
        substituters = [ "https://cache.numtide.com" ];
        trustedPublicKeys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
      };

      systemModule = import ./modules/system.nix { inherit packageFor binaryCache; };
    in
    {
      packages = forAllSystems (system: {
        default = packageFor system;
        claude-desktop = packageFor system;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${packageFor system}/bin/claude-desktop";
          meta.description = "Claude Desktop application";
        };
      });

      checks = forAllSystems (system: {
        claude-desktop = packageFor system;
      });

      overlays.default = final: _prev: {
        claude-desktop = packageFor final.stdenv.hostPlatform.system;
      };

      nixosModules.default = systemModule;
      darwinModules.default = systemModule;

      homeManagerModules.default = import ./modules/home-manager.nix { inherit packageFor; };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
