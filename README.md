# Claude Desktop flake

This flake packages Anthropic's official Claude Desktop build for Linux and
macOS by re-exporting the `claude-desktop` package from
[numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix) and adding
NixOS, nix-darwin and Home Manager modules around it.

Supported systems are `x86_64-linux`, `aarch64-linux` and `aarch64-darwin`.

The exact upstream revision is pinned in `flake.lock`. A GitHub Actions
workflow refreshes it every Monday, commits the result to `main` and, when the
Claude Desktop version changes, tags `v<version>` and publishes a release.
Update it by hand with:

```console
nix flake update llm-agents
```

## Binary cache

numtide builds every package daily and pushes it to `https://cache.numtide.com`.
This flake declares that cache in `nixConfig`, which Nix honours for direct
invocations when you pass `--accept-flake-config`. When the flake is consumed
as an input, enable the cache system-wide instead. The NixOS and nix-darwin
modules do this for you unless `programs.claude-desktop.enableBinaryCache` is
set to `false`.

Do not add `inputs.llm-agents.inputs.nixpkgs.follows` to your flake. The cache
only hits when the nixpkgs revision matches the one numtide built against.

## Run or install

```console
nix run --accept-flake-config github:mikekwright/claude-desktop-flake
nix profile install --accept-flake-config github:mikekwright/claude-desktop-flake
```

## Signing in

Sign-in opens claude.ai in the browser, which hands control back to the
application through a `claude://` URL via `xdg-open`. That only works when a
desktop entry declaring `x-scheme-handler/claude` is on `XDG_DATA_DIRS`, which
is the case once the package is installed into a profile. `nix run` never
installs anything, so sign-in cannot complete from a `nix run` session. Use
one of the modules below, or `nix profile install`, instead.

The NixOS and Home Manager modules also set Claude Desktop as the default
`claude://` handler explicitly. Turn that off with
`programs.claude-desktop.registerUrlHandler = false` if you manage MIME
defaults elsewhere.

## NixOS

```nix
{
  inputs.claude-desktop-flake.url = "github:mikekwright/claude-desktop-flake";

  outputs = { nixpkgs, claude-desktop-flake, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      modules = [
        claude-desktop-flake.nixosModules.default
        { programs.claude-desktop.enable = true; }
      ];
    };
  };
}
```

The same module is exported as `darwinModules.default` for nix-darwin.

Options:

| Option | Default | Description |
| --- | --- | --- |
| `programs.claude-desktop.enable` | `false` | Install Claude Desktop system-wide. |
| `programs.claude-desktop.package` | flake package | Package to install. |
| `programs.claude-desktop.enableBinaryCache` | `true` | Add the numtide substituter and key to `nix.settings`. |
| `programs.claude-desktop.registerUrlHandler` | `true` | Make Claude Desktop the system default for `claude://` URLs (NixOS only). |

## Home Manager

```nix
{
  imports = [ claude-desktop-flake.homeManagerModules.default ];

  programs.claude-desktop = {
    enable = true;
    settings = {
      globalShortcut = "Ctrl+Shift+Space";
    };
  };
}
```

Options:

| Option | Default | Description |
| --- | --- | --- |
| `programs.claude-desktop.enable` | `false` | Add Claude Desktop to `home.packages`. |
| `programs.claude-desktop.package` | flake package | Package to install. |
| `programs.claude-desktop.registerUrlHandler` | `true` | Register `claude://` in `xdg.mimeApps` and enable it (Linux only). |
| `programs.claude-desktop.settings` | `null` | Contents of `claude_desktop_config.json`. |

When `settings` is set, the configuration file is managed by Home Manager and
edits made inside the application will not persist. Leave it as `null` to let
the application own the file. On Linux the file is written to
`$XDG_CONFIG_HOME/Claude/`, on macOS to `~/Library/Application Support/Claude/`.

The Home Manager module does not touch Nix settings. Enable the binary cache
through the NixOS or nix-darwin module, or add it to `nix.settings` yourself:

```nix
nix.settings = {
  extra-substituters = [ "https://cache.numtide.com" ];
  extra-trusted-public-keys = [
    "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
  ];
};
```

## Overlay

`overlays.default` adds `pkgs.claude-desktop` for use in any nixpkgs
instantiation.

## Update workflow

`.github/workflows/update.yml` runs weekly and on demand. It records the
current version, runs `nix flake update llm-agents`, builds the package, and
commits `flake.lock` if it changed. When the version differs from the previous
one it also creates an annotated `v<version>` tag and a GitHub release that
links the upstream numtide commit. Lock updates that do not change the version
are committed without a tag.
