{ packageFor }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.claude-desktop;
  jsonFormat = pkgs.formats.json { };
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  configFileName = "claude_desktop_config.json";
  desktopFile = "com.anthropic.Claude.desktop";
  settingsFile = jsonFormat.generate configFileName cfg.settings;
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

    registerUrlHandler = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Register Claude Desktop as the default handler for claude:// URLs
        through xdg.mimeApps. The browser-based sign-in flow returns to the
        application through this scheme, so sign-in cannot complete without a
        handler. Enabling this turns on xdg.mimeApps, which makes Home Manager
        own ~/.config/mimeapps.list. Set to false if that file is managed
        elsewhere. Only applies on Linux.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.nullOr jsonFormat.type;
      default = null;
      example = lib.literalExpression ''
        {
          globalShortcut = "Ctrl+Shift+Space";
          mcpServers = { };
        }
      '';
      description = ''
        Contents of Claude Desktop's configuration file. When set, the file is
        managed declaratively and edits made from inside the application will
        not persist. Leave as null to let the application own the file.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.mimeApps = lib.mkIf (!isDarwin && cfg.registerUrlHandler) {
      enable = lib.mkDefault true;
      defaultApplications."x-scheme-handler/claude" = desktopFile;
    };

    home.file."Library/Application Support/Claude/${configFileName}" = lib.mkIf (
      isDarwin && cfg.settings != null
    ) { source = settingsFile; };

    xdg.configFile."Claude/${configFileName}" = lib.mkIf (!isDarwin && cfg.settings != null) {
      source = settingsFile;
    };
  };
}
