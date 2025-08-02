{
  description = "PSBBN Definitive English Patch env";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        psbbn = pkgs.writeScriptBin "psbbn" ''
          #!${pkgs.bash}/bin/bash
          ${builtins.concatStringsSep "\n" (
            builtins.tail (pkgs.lib.splitString "\n" (builtins.readFile ./PSBBN-Definitive-Patch.sh))
          )}
        '';

        psbbnInstaller = pkgs.writeScriptBin "psbbn-installer" ''
          #!${pkgs.bash}/bin/bash
          ${builtins.concatStringsSep "\n" (
            builtins.tail (pkgs.lib.splitString "\n" (builtins.readFile ./scripts/PSBBN-Installer.sh))
          )}
        '';

        gameInstaller = pkgs.writeScriptBin "game-installer" ''
          #!${pkgs.bash}/bin/bash
          ${builtins.concatStringsSep "\n" (
            builtins.tail (pkgs.lib.splitString "\n" (builtins.readFile ./scripts/Game-Installer.sh))
          )}
        '';

        mediaInstaller = pkgs.writeScriptBin "media-installer" ''
          #!${pkgs.bash}/bin/bash
          ${builtins.concatStringsSep "\n" (
            builtins.tail (pkgs.lib.splitString "\n" (builtins.readFile ./scripts/Media-Installer.sh))
          )}
        '';

        extras = pkgs.writeScriptBin "extras" ''
          #!${pkgs.bash}/bin/bash
          ${builtins.concatStringsSep "\n" (
            builtins.tail (pkgs.lib.splitString "\n" (builtins.readFile ./scripts/Extras.sh))
          )}
        '';

        pkgs = import nixpkgs { inherit system; };
        pythonEnv = pkgs.python3.withPackages (
          ps: with ps; [
            pip
            lz4
            natsort
            mutagen
            tqdm
          ]
        );
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bash
            pythonEnv
            axel
            imagemagick
            unixtools.xxd
            nodejs
            bc
            rsync
            curl
            zip
            unzip
            wget
            exfat
            chromium
            ffmpeg
            parted
            fuse2
            pkg-config
            patchelf

            psbbn
            psbbnInstaller
            gameInstaller
            mediaInstaller
            extras
          ];

          shellHook = ''
            ${pkgs.patchelf}/bin/patchelf --set-rpath "${pkgs.fuse2.out}/lib" "./scripts/helper/PFS Fuse.elf"
            mkdir -p scripts/venv/
            ln -sfn ${pythonEnv}/* ./scripts/venv/
            export PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
            export PUPPETEER_EXECUTABLE_PATH=${pkgs.chromium}/bin/chromium
            if ! npm list --prefix scripts puppeteer &> /dev/null; then
              echo "Installing puppeteer"
              npm install --prefix scripts puppeteer --silent
            fi

            echo -e "\033[1;32m==============================================================\033[0m"
            echo -e "\033[1;36m                PSBBN Definitive English Patch                \033[0m"
            echo -e "\033[1;32m==============================================================\033[0m"
            echo ""
            echo -e "\033[1;36mAvailable commands:\033[0m"
            echo -e "  \033[1;32mpsbbn\033[0m            - Main menu of PSBBN Definitive English Patch"
            echo -e "  \033[1;32mpsbbn-installer\033[0m  - Directly prepare a hard drive and install PSBBN"
            echo -e "  \033[1;32mgame-installer\033[0m   - Directly install or sync games to the prepared drive"
            echo -e "  \033[1;32mmedia-installer\033[0m  - Directly install or sync media to the prepared drive"
            echo -e "  \033[1;32mextras\033[0m           - Directly apply additional patches or tools"
            echo ""
            echo -e "Open main menu by executing: \033[1;36mpsbbn\033[0m"
            echo ""
          '';
        };

        apps = {
          psbbn = flake-utils.lib.mkApp { drv = psbbn; };
          psbbn-installer = flake-utils.lib.mkApp { drv = psbbnInstaller; };
          game-installer = flake-utils.lib.mkApp { drv = gameInstaller; };
          media-installer = flake-utils.lib.mkApp { drv = mediaInstaller; };
          extras = flake-utils.lib.mkApp { drv = extras; };
        };
      }
    );
}
