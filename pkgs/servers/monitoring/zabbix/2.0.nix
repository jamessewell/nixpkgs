{ stdenv, fetchurl, pkgconfig, postgresql, curl, openssl, zlib
, enableJabber ? false, minmay ? null }:

assert enableJabber -> minmay != null;

let

  version = "2.0.21";
  branch = "2.0";

  src = fetchurl {
    url = "mirror://sourceforge/zabbix/zabbix-${version}.tar.gz";
    sha256 = "14g22x2zy5xqnh2xg23xy5gjd49d1i8pks7pkidwdwa9acwgfx71";
  };

  preConfigure =
    ''
      substituteInPlace ./configure \
        --replace " -static" "" \
        ${stdenv.lib.optionalString (stdenv.cc.libc != null) ''
          --replace /usr/include/iconv.h ${stdenv.lib.getDev stdenv.cc.libc}/include/iconv.h
        ''}
    '';

in

{
  recurseForDerivations = true;

  server = stdenv.mkDerivation {
    name = "zabbix-${version}";

    inherit src preConfigure;

    configureFlags = [
      "--enable-agent"
      "--enable-server"
      "--with-postgresql"
      "--with-libcurl"
      "--with-gettext"
    ] ++ stdenv.lib.optional enableJabber "--with-jabber=${minmay}";

    postPatch = ''
      sed -i -e 's/iksemel/minmay/g' configure src/libs/zbxmedia/jabber.c
      sed -i \
        -e '/^static ikstransport/,/}/d' \
        -e 's/iks_connect_with\(.*\), &zbx_iks_transport/mmay_connect_via\1/' \
        -e 's/iks/mmay/g' -e 's/IKS/MMAY/g' src/libs/zbxmedia/jabber.c
    '';

  nativeBuildInputs = [ pkgconfig ];
    buildInputs = [ postgresql curl openssl zlib ];

    postInstall =
      ''
        mkdir -p $out/share/zabbix
        cp -prvd frontends/php $out/share/zabbix/php
        mkdir -p $out/share/zabbix/db/data
        cp -prvd database/postgresql/data.sql $out/share/zabbix/db/data/data.sql
        cp -prvd database/postgresql/images.sql $out/share/zabbix/db/data/images_pgsql.sql
        mkdir -p $out/share/zabbix/db/schema
        cp -prvd database/postgresql/schema.sql $out/share/zabbix/db/schema/postgresql.sql
      '';

    meta = {
      inherit branch;
      description = "An enterprise-class open source distributed monitoring solution";
      homepage = https://www.zabbix.com/;
      license = "GPL";
      maintainers = [ stdenv.lib.maintainers.eelco ];
      platforms = stdenv.lib.platforms.linux;
    };
  };

  agent = stdenv.mkDerivation {
    name = "zabbix-agent-${version}";

    inherit src preConfigure;

    configureFlags = [ "--enable-agent" ];

    meta = with stdenv.lib; {
      inherit branch;
      description = "An enterprise-class open source distributed monitoring solution (client-side agent)";
      homepage = https://www.zabbix.com/;
      license = licenses.gpl2;
      maintainers = [ maintainers.eelco ];
      platforms = platforms.linux;
    };
  };

}
