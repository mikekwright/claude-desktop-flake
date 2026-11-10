{ packageFor, binaryCache }:
{
  config,
  options,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude-desktop;
  desktopFile = "com.anthropic.Claude.desktop";
  hasXdgMime = options ? xdg.mime;
in
{
  options.programs.claude-desktop = {
    enable = lib.mkEnableOption "Claude Desktop";

    package = lib.mkOption {
      type = lib.types.package;
      default = packageFor pkgs.stdenv.hostPlatform.system;
      defaultText = lib.literalExpression "claude-desktop-flake.packages.\${system}.claude-desktop";
      description = "The Claude Desktop package to install.";
    };

    enableBinaryCache = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Add the numtide binary cache to the system Nix settings so the
        prebuilt Claude Desktop closure is downloaded instead of rebuilt.
      '';
    };

    registerUrlHandler = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Register Claude Desktop as the system default handler for claude://
        URLs. The browser-based sign-in flow returns to the application
        through this scheme, so sign-in cannot complete without a handler.
        Only applies on NixOS; macOS registers the scheme from the app bundle.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    {
      environment.systemPackages = [ cfg.package ];

      nix.settings = lib.mkIf cfg.enableBinaryCache {
        extra-substituters = binaryCache.substituters;
        extra-trusted-public-keys = binaryCache.trustedPublicKeys;
      };
    }
    // lib.optionalAttrs hasXdgMime {
      xdg.mime.defaultApplications = lib.mkIf cfg.registerUrlHandler {
        "x-scheme-handler/claude" = desktopFile;
      };
    }
  );
}
