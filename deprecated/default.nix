{
  stdenv,
  clang-tools,
  python3,
  ...
}:

stdenv.mkDerivation {
  pname = "water";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [
    clang-tools
    python3
  ];

  makeFlags = [ "dist" ];

  installPhase = ''
    mkdir -p $out/bin
    cp bin/dist/water $out/bin/
  '';

}
