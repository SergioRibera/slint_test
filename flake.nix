{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (baseSystem:
      let
        # cargoManifest = builtins.fromTOML (builtins.readFile ./Cargo.toml);
        # architectures = import ./architectures.nix;

        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          system = baseSystem;
          inherit overlays;
        };

        libraries = with pkgs; [
          libGL
          libxkbcommon
          wayland

          xorg.libX11
          xorg.libXcursor
          xorg.libXi
          xorg.libXrandr
        ];

        packages= with pkgs; [
          slint-lsp

          openssl.dev
          pkg-config
          wayland
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          inherit packages;
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath libraries}";
        };
      });
}
