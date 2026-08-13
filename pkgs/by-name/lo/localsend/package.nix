{
  lib,
  stdenv,
  fetchurl,
  fetchFromGitHub,
  flutter341,
  rustPlatform,
  cacert,
  writeText,
  makeDesktopItem,
  copyDesktopItems,
  nixosTests,
  libayatana-appindicator,
  undmg,
  makeBinaryWrapper,
}:

let
  pname = "localsend";
  version = "1.18.0";

  src = fetchFromGitHub {
    owner = "localsend";
    repo = "localsend";
    tag = "v${version}";
    hash = "sha256-AmQVXGMVKLTOZ0HMi05ba/y4TmB56NlNvtGaKYvqt4o=";
  };

  rustDep = rustPlatform.buildRustPackage {
    inherit pname version src;

    cargoHash = "sha256-mdyWYfzS6YieY+dwQXREZJDo4PEKO5W9C3A3XGWoDKI=";
    cargoBuildFlags = [ "--package=rust_lib_localsend_app" ];
    cargoTestFlags = [
      "--package=localsend"
      "--package=rust_lib_localsend_app"
    ];

    nativeCheckInputs = [ cacert ];

    postInstall = ''
      rm $out/lib/librust_lib_localsend_app.a
    '';

    passthru.libraryPath = "lib/librust_lib_localsend_app.so";
  };

  linux = flutter341.buildFlutterApplication rec {
    inherit pname version src;

    sourceRoot = "${src.name}/app";

    pubspecLock = lib.importJSON ./pubspec.lock.json;

    gitHashes = lib.importJSON ./git-hashes.json;

    customSourceBuilders.rust_lib_localsend_app =
      { version, src, ... }:
      stdenv.mkDerivation {
        pname = "rust_lib_localsend_app";
        inherit version src;
        inherit (src) passthru;

        postPatch =
          let
            fakeCargokitCmake = writeText "FakeCargokit.cmake" ''
              function(apply_cargokit target manifest_dir lib_name any_symbol_name)
                set("''${target}_cargokit_lib" ${rustDep}/${rustDep.passthru.libraryPath} PARENT_SCOPE)
              endfunction()
            '';
          in
          ''
            cp ${fakeCargokitCmake} packages/localsend_isolates/rust_builder/cargokit/cmake/cargokit.cmake
          '';

        installPhase = ''
          runHook preInstall

          cp -r . "$out"

          runHook postInstall
        '';
      };

    postPatch = ''
      substituteInPlace lib/util/native/autostart_helper.dart \
        --replace-fail 'Exec=''${Platform.resolvedExecutable}' "Exec=localsend_app"
    '';

    nativeBuildInputs = [
      copyDesktopItems
    ];

    buildInputs = [ libayatana-appindicator ];

    postInstall = ''
      for s in 32 128 256 512; do
        d=$out/share/icons/hicolor/''${s}x''${s}/apps
        mkdir -p $d
        cp ./assets/img/logo-''${s}.png $d/localsend.png
      done
    '';

    extraWrapProgramArgs = ''
      --prefix LD_LIBRARY_PATH : $out/app/localsend/lib
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "LocalSend";
        exec = "localsend_app %U";
        icon = "localsend";
        desktopName = "LocalSend";
        startupWMClass = "localsend_app";
        genericName = "An open source cross-platform alternative to AirDrop";
        categories = [
          "GTK"
          "FileTransfer"
          "Utility"
        ];
        keywords = [
          "Sharing"
          "LAN"
          "Files"
        ];
        startupNotify = true;
      })
    ];

    passthru = {
      inherit rustDep;
      updateScript = ./update.sh;
      tests.localsend = nixosTests.localsend;
    };

    meta = metaCommon // {
      mainProgram = "localsend_app";
    };
  };

  darwin = stdenv.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url = "https://github.com/localsend/localsend/releases/download/v${version}/LocalSend-${version}.dmg";
      hash = "sha256-k6uITCcDoPq9cmEQl7JhbA3vhsQlbOoq3XoP823Xazo=";
    };

    nativeBuildInputs = [
      undmg
      makeBinaryWrapper
    ];

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/Applications
      cp -r LocalSend.app $out/Applications
      makeBinaryWrapper $out/Applications/LocalSend.app/Contents/MacOS/LocalSend $out/bin/localsend

      runHook postInstall
    '';

    meta = metaCommon // {
      mainProgram = "localsend";
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      platforms = [
        "aarch64-darwin"
      ];
    };
  };

  metaCommon = {
    description = "Open source cross-platform alternative to AirDrop";
    homepage = "https://localsend.org/";
    donationPage = "https://localsend.org/donate";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      sikmir
      linsui
      pandapip1
      sadroad
    ];
  };
in
if stdenv.hostPlatform.isDarwin then darwin else linux
