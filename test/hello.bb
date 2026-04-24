# Sample BitBake recipe for smoke-testing the Zed extension
SUMMARY = "Hello World package"
DESCRIPTION = "A minimal test recipe"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://LICENSE;md5=abc123"

HELLO_VERSION = "1.0"
SRC_URI = "git://github.com/example/hello.git;protocol=https;branch=main"
SRCREV = "abc123def456"

S = "${WORKDIR}/hello-${HELLO_VERSION}"

inherit autotools pkgconfig

do_configure() {
    ./configure --prefix=${D}${prefix} --enable-static
}

do_compile() {
    oe_runmake
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 hello ${D}${bindir}/hello
}

python do_display_banner() {
    bb.plain("Building hello world")
    version = d.getVar('HELLO_VERSION')
    if version:
        bb.warn("Version: %s" % version)
}

addtask do_display_banner before do_configure after do_fetch

PACKAGES =+ "hello-dev"
FILES:hello-dev = "${includedir}/*"
