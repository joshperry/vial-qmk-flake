{
  # Probably need to add `services.udev.packages = [ pkgs.qmk-udev-rules ];` to `configuration.nix`.
  description = "Flake for building vial-qmk firmware";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
  inputs.nixos-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

  # The vial fork of qmk, stores the keyboard config in on-keyboard memory. and 
  # supports the `Vial` GUI key map config app.
  inputs.vial-qmk = {
    url = "git+https://github.com/vial-kb/vial-qmk.git?submodules=1&ref=vial";
    flake = false;
  };

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, nixos-unstable, vial-qmk, flake-utils }:
    # This effectively appends `.x86_64-linux` the attributes returned
    # by the function passed in. The `system` parameter is also that string.
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
    let
      pkgs = import nixpkgs { inherit system;
        overlays = [
          #pkgs.unstable
          (final: prev: {
            unstable = nixos-unstable.legacyPackages."${prev.system}";
          })
        ];
      };
    in
    {
      # Meant for consumption via `nix develop`
      devShell = pkgs.mkShell {
        # Put what you want here
        KEYBOARD="keychron/s1/ansi/rgb";
        KEYMAP="vial";

        #buildInputs = [ packages.default ];
        buildInputs = [ pkgs.qmk pkgs.unstable.vial ];
        VIAL_QMK_DIR="${vial-qmk}";
        # `COPY=echo` is a hack here to neuter all uses of `COPY`, which are only
        # sending files to readonly vial-qmk src dir.
        # A patch fixup probably makes most sense in a more fully fleshed-out impl

        # Alias commands for building and flashing
        shellHook = ''
          alias build="make -C ${vial-qmk} BUILD_DIR=`pwd`/build COPY=echo -j8 $KEYBOARD:$KEYMAP"
          alias flash="make -C ${vial-qmk} BUILD_DIR=`pwd`/build COPY=echo -j8 $KEYBOARD:$KEYMAP:flash"
          echo 'hi! run `build` to build the firmware, and `flash` to, well, flash it.'
          echo 'take a look in the `flake.nix` if you want to change the '"keyboard($KEYBOARD) and/or map($KEYMAP)."
        '';
      };

      # Not really used, best way to interact with this currenty is via `nix develop`
      packages.default = pkgs.stdenv.mkDerivation {
        name = "vial_qmk_firmware";
        src = ./.;
        buildInputs = [ pkgs.qmk pkgs.unstable.vial pkgs.vial-qmk ];
        VIAL_QMK_DIR="${vial-qmk}";
        buildPhase = ''
          mkdir -p `pwd`/build
          make -C ${vial-qmk} BUILD_DIR=`pwd`/build COPY=echo -j8 keychron/s1/ansi/rgb:vial
        '';
        installPhase = ''
          mkdir -p $out
          cp build/*.bin $out/
        '';
      };
    }
  );
}
