SUMMARY = "A parallel implementation of gzip"
DESCRIPTION = "pigz, which stands for parallel implementation of gzip, is a \
fully functional replacement for gzip that exploits multiple processors and \
multiple cores to the hilt when compressing data. pigz was written by Mark \
Adler, and uses the zlib and pthread libraries."
HOMEPAGE = "http://zlib.net/pigz/"
SECTION = "console/utils"
LICENSE = "Zlib & Apache-2.0"

SRC_URI = "http://zlib.net/${BPN}/${BP}.tar.gz"

PROVIDES_class-native += "gzip-native"

DEPENDS = "zlib"

do_install_class-target() {
	# Install files into /bin (FHS), which is typical place for gzip
	install -d ${D}${base_bindir}
	install ${B}/pigz ${D}${base_bindir}/gzip
	install ${B}/unpigz ${D}${base_bindir}/gunzip
}

do_install() {
	install -d ${D}${bindir}
	install ${B}/pigz ${D}${bindir}/gzip
	install ${B}/unpigz ${D}${bindir}/gunzip
}

ALTERNATIVE_${PN} = "gzip gunzip"
ALTERNATIVE_LINK_NAME[gzip] = "${base_bindir}/gzip"
ALTERNATIVE_LINK_NAME[gunzip] = "${base_bindir}/gunzip"
ALTERNATIVE_PRIORITY = "80"
