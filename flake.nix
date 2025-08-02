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

        psbbnInstaller = pkgs.writeShellScriptBin "psbbn-installer" (
          builtins.readFile ./02-PSBBN-Installer.sh
        );

        gameInstaller = pkgs.writeShellScriptBin "game-installer" (
          builtins.readFile ./03-Game-Installer.sh
        );

        extras = pkgs.writeShellScriptBin "extras" (builtins.readFile ./04-Extras.sh);

        pkgs = import nixpkgs { inherit system; };
        pythonEnv = pkgs.python3.withPackages (
          ps: with ps; [
            pip
            lz4
            natsort
          ]
        );
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
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

            psbbnInstaller
            gameInstaller
            extras
          ];
          shellHook = ''
            if ! npm list puppeteer &> /dev/null; then
              echo "Installing puppeteer using npm"
              npm install puppeteer
            fi

            GREEN='\033[1;32m'
            CYAN='\033[1;36m'
            NC='\033[0m' # No Color

            echo -e "\033[1;32m==============================================================\033[0m"
            echo -e "\033[1;36mPSBBN Definitive English Patch Development Environment Ready\033[0m"
            echo -e "\033[1;32m==============================================================\033[0m"
            echo ""
            echo -e "\033[1;36mAvailable commands:\033[0m"
            echo -e "  \033[1;32mpsbbn-installer\033[0m  - Prepare a hard drive and install PSBBN"
            echo -e "  \033[1;32mgame-installer\033[0m   - Install or sync games to the prepared drive"
            echo -e "  \033[1;32mextras\033[0m           - Apply additional patches or tools"
            echo ""
            echo -e "Start with: \033[1;36mpsbbn-installer\033[0m, then use \033[1;36mgame-installer\033[0m as needed."
            echo ""
          '';
        };

        # Apps for direct execution with `nix run .#<name>`
        apps = {
          psbbn-installer = flake-utils.lib.mkApp { drv = psbbnInstaller; };
          game-installer = flake-utils.lib.mkApp { drv = gameInstaller; };
          extras = flake-utils.lib.mkApp { drv = extras; };
        };
      }
    );
}
