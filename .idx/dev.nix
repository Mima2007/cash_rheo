{ pkgs, ... }: {
  channel = "stable-24.05";
  packages = [
    pkgs.jdk17
    pkgs.unzip
    pkgs.curl
  ];
  env = {
    JAVA_HOME = "${pkgs.jdk17}";
  };
}
