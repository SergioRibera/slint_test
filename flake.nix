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
        cargoManifest = builtins.fromTOML (builtins.readFile ./Cargo.toml);
        # architectures = import ./architectures.nix;

        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          system = baseSystem;
          inherit overlays;
          config.allowUnfree = true;
        };

        libraries = with pkgs; [
          libGL
          fontconfig
          pkgs.stdenv.cc.cc.lib
          rustPlatform.bindgenHook
          xorg.libX11
          xorg.libxcb
          freetype
          libxkbcommon

          wayland

          libjpeg
          vulkan-loader
        ];

        appPkg = (pkgs.rustPlatform.buildRustPackage.override { stdenv = pkgs.clangStdenv; }) (finalAttrs: {
          pname = cargoManifest.package.name;
          version = cargoManifest.package.version;
          src = ./.;
          cargoLock.lockFile = ./Cargo.lock;
          doCheck = false;

        nativeBuildInputs = with pkgs;
          [
            pkg-config
            python3
            makeWrapper
            removeReferencesTo

            rustPlatform.bindgenHook
            autoPatchelfHook
          ] ++ lib.optionals stdenv.buildPlatform.isDarwin [
            libiconv
            cctools.libtool
          ];
        runtimeDependencies = with pkgs;
          [ noto-fonts-color-emoji ]
          ++ lib.optionals stdenv.isLinux [
            wayland
            libxkbcommon
          ];

        makeWrapperArgs = [
          "--prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath libraries}"
        ];
        buildInputs = libraries;

        postFixup = ''
          remove-references-to -t "$SKIA_SOURCE_DIR" $out/bin/${cargoManifest.package.name}
          patchelf --set-rpath "${pkgs.lib.makeLibraryPath libraries}" $out/bin/${cargoManifest.package.name}
        '';
        disallowedReferences = [ finalAttrs.SKIA_SOURCE_DIR ];

        SKIA_NINJA_COMMAND = "${pkgs.ninja}/bin/ninja";
        SKIA_GN_COMMAND = "${pkgs.gn}/bin/gn";
        SKIA_ENABLE_TOOLS = "false";
        SKIA_LIBRARY_DIR = "${pkgs.skia}/lib";
        SKIA_SOURCE_DIR =
          let
            repo = pkgs.fetchFromGitHub {
              owner = "rust-skia";
              repo = "skia";
              # see rust-skia:skia-bindings/Cargo.toml#package.metadata skia
              tag = "m138-0.86.2";
              hash = "sha256-35dQPlvE5mvFv+bvdKG1r9tme8Ba5hnuepVbUp1J9S4=";
            };
            # The externals for skia are taken from skia/DEPS
            externals = pkgs.linkFarm "skia-externals" (
              pkgs.lib.mapAttrsToList (name: value: {
                inherit name;
                path = pkgs.fetchgit value;
              }) (pkgs.lib.importJSON ./skia-externals.json)
            );
          in
          pkgs.runCommand "source" { } ''
            cp -R ${repo} $out
            chmod -R +w $out
            ln -s ${externals} $out/third_party/externals
          '';
        });
      in
      {
        apps.default = {
            type = "app";
            program = "${appPkg}/bin/${cargoManifest.package.name}";
        };
        packages.default = appPkg;
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            slint-lsp

            openssl.dev
            pkg-config
            wayland
          ] ++ libraries;
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath libraries}";
        };
      });
}
