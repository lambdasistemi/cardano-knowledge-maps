{ pkgs }:

# EYE (Euler Yet another proof Engine) — N3 / OWL 2 RL reasoner used by
# the cardano-tx-tools epic (cardano-tx-tools#46) for `owl:sameAs`
# deduction via `owl:hasKey`. Packaged here so the gate.sh OWL 2 RL
# inference smoke (Phase B) can run inside `nix develop -c …` without
# network access at run time.
#
# Build follows upstream install.sh: compile eye.pl into a SWI-Prolog
# image (eye.pvm) and install a tiny launcher script.

let
  src = pkgs.fetchFromGitHub {
    owner = "eyereasoner";
    repo = "eye";
    rev = "v11.24.4";
    hash = "sha256-DKpKu1ELN68Wfd6MoAE3nWU414MoukEZRInUQB96sWU=";
  };
in
pkgs.stdenv.mkDerivation {
  pname = "eye";
  version = "11.24.4";
  inherit src;

  nativeBuildInputs = [ pkgs.swi-prolog pkgs.makeWrapper ];
  buildInputs = [ pkgs.swi-prolog ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    mkdir -p $out/lib $out/bin
    swipl -q -f ./eye.pl -g main -- --quiet --image $out/lib/eye.pvm
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    substitute eye.sh.in $out/bin/eye --replace-fail '@PREFIX@' "$out"
    chmod 0755 $out/bin/eye
    # The launcher invokes `swipl`; wrap so it's reachable at runtime.
    wrapProgram $out/bin/eye \
      --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.swi-prolog ]}
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    actual=$($out/bin/eye --version 2>&1)
    case "$actual" in
      *"EYE v11.24.4"*) ;;
      *) echo "eye --version did not report 11.24.4: $actual" >&2; exit 1 ;;
    esac
    runHook postInstallCheck
  '';

  meta = with pkgs.lib; {
    description = "Euler Yet another proof Engine — N3 / OWL 2 RL reasoner";
    homepage = "https://github.com/eyereasoner/eye";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "eye";
  };
}
