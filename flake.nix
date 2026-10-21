{
  description = "NEET OS Live Installer Flake";

  inputs = {
    # NEET OS のリポジトリ
    neet-os.url = "github:Benzenec6h6/NEET_OS";
  };

  outputs = {
    self,
    neet-os,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = neet-os.legacyPackages.${system};

    # NEET OS のシステム評価（リポジトリの提供する builder に応じて調整）
    installerSystem = neet-os.lib.evalSystem {
      inherit system;
      modules = [
        # インストーラ機能を有効化
        {
          installer.enable = true;
          services.iwd.enable = true;
          services.openssh = {
            enable = true;
            startOnBoot = false;
            settings = {
              PermitRootLogin = "yes"; # パスワードログインを許可
            };
          };
          boot.console.keyMap = "jp106";
          programs.coreutils.package = pkgs.uutils-coreutils-noprefix;
          services.getty.autologinUser = "neet";

          neet.users = {
            root = {
              uid = 0;
              gid = 0;
              shell = "/bin/bash";
              home = "/root";
              description = "System Administrator";
              initialHashedPassword = "";
            };
            neet = {
              uid = 1000;
              gid = 1000;
              shell = "/bin/bash";
              home = "/home/neet";
              description = "Primary User";
              extraGroups = ["audio" "video" "input" "seat" "wheel"];
              initialHashedPassword = "";
            };
          };
          # 必要に応じてホスト名やキーマップなどを追加
          networking.hostName = "neet-installer";
        }
      ];
    };
  in {
    packages.${system} = {
      # nix build .#installer で .img.zst をビルド
      installer = installerSystem.config.system.build.diskImageZst;
      default = self.packages.${system}.installer;
    };

    apps.${system} = {
      flash = {
        type = "app";
        program = "${pkgs.writeShellScript "flash-installer" ''
          set -euo pipefail
          target="''${1:?usage: nix run .#flash -- <device> (e.g. /dev/sdb)}"
          # ★ ディレクトリ配下のイメージファイルを指定
          img="${self.packages.${system}.installer}/neet-live-image.img.zst"

          echo "WARNING: All data on $target will be erased!"
          read -p "Are you sure? (y/N) " -n 1 -r
          echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Flashing to $target..."
            ${pkgs.zstd}/bin/zstdcat "$img" | dd of="$target" bs=4M status=progress oflag=sync
            echo "Done!"
          fi
        ''}";
      };
    };
  };
}
