{
  lib,
  mkShell,
  makeFontsConf,
  pkgsCross,

  zed,

  rust-analyzer,
  rustup,
  cargo-nextest,
  cargo-hakari,
  cargo-machete,
  cargo-zigbuild,
  nixfmt-rfc-style,
  protobuf,
  nodejs_22,
  zig,
}:
let
  allCrateBuilds = lib.pipe zed.workspace.workspaceMembers [
    builtins.attrValues
    (map (
      c:
      ((builtins.getAttr "build" c).overrideAttrs (attrs: {
        passthru = {
          env = attrs.env or { };
        };
      }))
    ))
  ];
in
(mkShell.override { inherit (zed.workspace.workspaceMembers.zed.build) stdenv; }) {
  inputsFrom = allCrateBuilds;
  inputs = [
    rust-analyzer
    rustup
    cargo-nextest
    cargo-hakari
    cargo-machete
    cargo-zigbuild
    nixfmt-rfc-style
    # TODO: package protobuf-language-server for editing zed.proto
    # TODO: add other tools used in our scripts

    # `build.nix` adds this to the `zed-editor` wrapper (see `postFixup`)
    # we'll just put it on `$PATH`:
    nodejs_22
    zig
  ];

  env =
    let
      baseEnvs = (lib.foldr (c: acc: acc // c.env) { }) allCrateBuilds;
    in
    (removeAttrs baseEnvs [
      "LK_CUSTOM_WEBRTC" # download the staticlib during the build as usual
      "ZED_UPDATE_EXPLANATION" # allow auto-updates
      "CARGO_PROFILE" # let you specify the profile
      "TARGET_DIR"
    ])
    // {
      # note: different than `$FONTCONFIG_FILE` in `build.nix` – this refers to relative paths
      # outside the nix store instead of to `$src`
      FONTCONFIG_FILE = makeFontsConf {
        fontDirectories = [
          "./assets/fonts/lilex"
          "./assets/fonts/ibm-plex-sans"
        ];
      };
      PROTOC = "${protobuf}/bin/protoc";
      ZED_ZSTD_MUSL_LIB = "${pkgsCross.musl64.pkgsStatic.zstd.out}/lib";
    };
}
