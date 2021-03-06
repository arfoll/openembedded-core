# ex:ts=4:sw=4:sts=4:et
# -*- tab-width: 4; c-basic-offset: 4; indent-tabs-mode: nil -*-
#
# This bbclass is used for creating archive for:
# 1) original (or unpacked) source: ARCHIVER_MODE[src] = "original"
# 2) patched source: ARCHIVER_MODE[src] = "patched" (default)
# 3) configured source: ARCHIVER_MODE[src] = "configured"
# 4) The patches between do_unpack and do_patch:
#    ARCHIVER_MODE[diff] = "1"
#    And you can set the one that you'd like to exclude from the diff:
#    ARCHIVER_MODE[diff-exclude] ?= ".pc autom4te.cache patches"
# 5) The environment data, similar to 'bitbake -e recipe':
#    ARCHIVER_MODE[dumpdata] = "1"
# 6) The recipe (.bb and .inc): ARCHIVER_MODE[recipe] = "1"
# 7) Whether output the .src.rpm package:
#    ARCHIVER_MODE[srpm] = "1"
# 8) Filter the license, the recipe whose license in
#    COPYLEFT_LICENSE_INCLUDE will be included, and in
#    COPYLEFT_LICENSE_EXCLUDE will be excluded.
#    COPYLEFT_LICENSE_INCLUDE = 'GPL* LGPL*'
#    COPYLEFT_LICENSE_EXCLUDE = 'CLOSED Proprietary'
# 9) The recipe type that will be archived:
#    COPYLEFT_RECIPE_TYPES = 'target'
#

# Don't filter the license by default
COPYLEFT_LICENSE_INCLUDE ?= ''
COPYLEFT_LICENSE_EXCLUDE ?= ''
# Create archive for all the recipe types
COPYLEFT_RECIPE_TYPES ?= 'target native nativesdk cross crosssdk cross-canadian'
inherit copyleft_filter

ARCHIVER_MODE[srpm] ?= "0"
ARCHIVER_MODE[src] ?= "patched"
ARCHIVER_MODE[diff] ?= "0"
ARCHIVER_MODE[diff-exclude] ?= ".pc autom4te.cache patches"
ARCHIVER_MODE[dumpdata] ?= "0"
ARCHIVER_MODE[recipe] ?= "0"

DEPLOY_DIR_SRC ?= "${DEPLOY_DIR}/sources"
ARCHIVER_TOPDIR ?= "${WORKDIR}/deploy-sources"
ARCHIVER_OUTDIR = "${ARCHIVER_TOPDIR}/${TARGET_SYS}/${PF}/"
ARCHIVER_WORKDIR = "${WORKDIR}/archiver-work/"

do_dumpdata[dirs] = "${ARCHIVER_OUTDIR}"
do_ar_recipe[dirs] = "${ARCHIVER_OUTDIR}"
do_ar_original[dirs] = "${ARCHIVER_OUTDIR} ${ARCHIVER_WORKDIR}"

# This is a convenience for the shell script to use it


python () {
    pn = d.getVar('PN', True)

    if d.getVar('COPYLEFT_LICENSE_INCLUDE', True) or \
            d.getVar('COPYLEFT_LICENSE_EXCLUDE', True):
        included, reason = copyleft_should_include(d)
        if not included:
            bb.debug(1, 'archiver: %s is excluded: %s' % (pn, reason))
            return
        else:
            bb.debug(1, 'archiver: %s is included: %s' % (pn, reason))

    ar_src = d.getVarFlag('ARCHIVER_MODE', 'src', True)
    ar_dumpdata = d.getVarFlag('ARCHIVER_MODE', 'dumpdata', True)
    ar_recipe = d.getVarFlag('ARCHIVER_MODE', 'recipe', True)

    if ar_src == "original":
        d.appendVarFlag('do_deploy_archives', 'depends', ' %s:do_ar_original' % pn)
    elif ar_src == "patched":
        d.appendVarFlag('do_deploy_archives', 'depends', ' %s:do_ar_patched' % pn)
    elif ar_src == "configured":
        # We can't use "addtask do_ar_configured after do_configure" since it
        # will cause the deptask of do_populate_sysroot to run not matter what
        # archives we need, so we add the depends here.
        d.appendVarFlag('do_ar_configured', 'depends', ' %s:do_configure' % pn)
        d.appendVarFlag('do_deploy_archives', 'depends', ' %s:do_ar_configured' % pn)
    elif ar_src:
        bb.fatal("Invalid ARCHIVER_MODE[src]: %s" % ar_src)

    if ar_dumpdata == "1":
        d.appendVarFlag('do_deploy_archives', 'depends', ' %s:do_dumpdata' % pn)

    if ar_recipe == "1":
        d.appendVarFlag('do_deploy_archives', 'depends', ' %s:do_ar_recipe' % pn)

    # Output the srpm package
    ar_srpm = d.getVarFlag('ARCHIVER_MODE', 'srpm', True)
    if ar_srpm == "1":
        if d.getVar('PACKAGES', True) != '' and d.getVar('IMAGE_PKGTYPE', True) == 'rpm':
            d.appendVarFlag('do_deploy_archives', 'depends', ' %s:do_package_write_rpm' % pn)
            if ar_dumpdata == "1":
                d.appendVarFlag('do_package_write_rpm', 'depends', ' %s:do_dumpdata' % pn)
            if ar_recipe == "1":
                d.appendVarFlag('do_package_write_rpm', 'depends', ' %s:do_ar_recipe' % pn)
            if ar_src == "original":
                d.appendVarFlag('do_package_write_rpm', 'depends', ' %s:do_ar_original' % pn)
            elif ar_src == "patched":
                d.appendVarFlag('do_package_write_rpm', 'depends', ' %s:do_ar_patched' % pn)
            elif ar_src == "configured":
                d.appendVarFlag('do_package_write_rpm', 'depends', ' %s:do_ar_configured' % pn)

    # The gcc staff uses shared source
    flag = d.getVarFlag("do_unpack", "stamp-base", True)
    if flag:
        if ar_src in [ 'original', 'patched' ]:
            ar_outdir = os.path.join(d.getVar('ARCHIVER_TOPDIR', True), 'work-shared')
            d.setVar('ARCHIVER_OUTDIR', ar_outdir)
        d.setVarFlag('do_ar_original', 'stamp-base', flag)
        d.setVarFlag('do_ar_patched', 'stamp-base', flag)
        d.setVarFlag('do_unpack_and_patch', 'stamp-base', flag)
        d.setVarFlag('do_ar_original', 'vardepsexclude', 'PN PF ARCHIVER_OUTDIR WORKDIR')
        d.setVarFlag('do_unpack_and_patch', 'vardepsexclude', 'PN PF ARCHIVER_OUTDIR WORKDIR')
        d.setVarFlag('do_ar_patched', 'vardepsexclude', 'PN PF ARCHIVER_OUTDIR WORKDIR')
        d.setVarFlag('create_diff_gz', 'vardepsexclude', 'PF')
        d.setVarFlag('create_tarball', 'vardepsexclude', 'PF')

        flag_clean = d.getVarFlag('do_unpack', 'stamp-base-clean', True)
        if flag_clean:
            d.setVarFlag('do_ar_original', 'stamp-base-clean', flag_clean)
            d.setVarFlag('do_ar_patched', 'stamp-base-clean', flag_clean)
            d.setVarFlag('do_unpack_and_patch', 'stamp-base-clean', flag_clean)
}

# Take all the sources for a recipe and puts them in WORKDIR/archiver-work/.
# Files in SRC_URI are copied directly, anything that's a directory
# (e.g. git repositories) is "unpacked" and then put into a tarball.
python do_ar_original() {

    import shutil, tarfile, tempfile

    if d.getVarFlag('ARCHIVER_MODE', 'src', True) != "original":
        return

    ar_outdir = d.getVar('ARCHIVER_OUTDIR', True)
    bb.note('Archiving the original source...')
    fetch = bb.fetch2.Fetch([], d)
    for url in fetch.urls:
        local = fetch.localpath(url).rstrip("/");
        if os.path.isfile(local):
            shutil.copy(local, ar_outdir)
        elif os.path.isdir(local):
            basename = os.path.basename(local)

            tmpdir = tempfile.mkdtemp(dir=d.getVar('ARCHIVER_WORKDIR', True))
            fetch.unpack(tmpdir, (url,))

            os.chdir(tmpdir)
            # We eliminate any AUTOINC+ in the revision.
            try:
                src_rev = bb.fetch2.get_srcrev(d).replace('AUTOINC+','')
            except:
                src_rev = 'NOREV'
            tarname = os.path.join(ar_outdir, basename + '.' + src_rev + '.tar.gz')
            tar = tarfile.open(tarname, 'w:gz')
            tar.add('.')
            tar.close()

    # Emit patch series files for 'original'
    bb.note('Writing patch series files...')
    for patch in src_patches(d):
        _, _, local, _, _, parm = bb.fetch.decodeurl(patch)
        patchdir = parm.get('patchdir')
        if patchdir:
            series = os.path.join(ar_outdir, 'series.subdir.%s' % patchdir.replace('/', '_'))
        else:
            series = os.path.join(ar_outdir, 'series')

        with open(series, 'a') as s:
            s.write('%s -p%s\n' % (os.path.basename(local), parm['striplevel']))
}

python do_ar_patched() {

    if d.getVarFlag('ARCHIVER_MODE', 'src', True) != 'patched':
        return

    # Get the ARCHIVER_OUTDIR before we reset the WORKDIR
    ar_outdir = d.getVar('ARCHIVER_OUTDIR', True)
    bb.note('Archiving the patched source...')
    d.setVar('WORKDIR', d.getVar('ARCHIVER_WORKDIR', True))
    # The gcc staff uses shared source
    flag = d.getVarFlag('do_unpack', 'stamp-base', True)
    if flag:
        create_tarball(d, d.getVar('S', True), 'patched', ar_outdir, 'gcc')
    else:
        create_tarball(d, d.getVar('S', True), 'patched', ar_outdir)
}

python do_ar_configured() {
    import shutil

    ar_outdir = d.getVar('ARCHIVER_OUTDIR', True)
    if d.getVarFlag('ARCHIVER_MODE', 'src', True) == 'configured':
        bb.note('Archiving the configured source...')
        # The libtool-native's do_configure will remove the
        # ${STAGING_DATADIR}/aclocal/libtool.m4, so we can't re-run the
        # do_configure, we archive the already configured ${S} to
        # instead of.
        if d.getVar('PN', True) != 'libtool-native':
            # Change the WORKDIR to make do_configure run in another dir.
            d.setVar('WORKDIR', d.getVar('ARCHIVER_WORKDIR', True))
            if bb.data.inherits_class('kernel-yocto', d):
                bb.build.exec_func('do_kernel_configme', d)
            if bb.data.inherits_class('cmake', d):
                bb.build.exec_func('do_generate_toolchain_file', d)
            prefuncs = d.getVarFlag('do_configure', 'prefuncs', True)
            for func in (prefuncs or '').split():
                if func != "sysroot_cleansstate":
                    bb.build.exec_func(func, d)
            bb.build.exec_func('do_configure', d)
            postfuncs = d.getVarFlag('do_configure', 'postfuncs', True)
            for func in (postfuncs or '').split():
                if func != "do_qa_configure":
                    bb.build.exec_func(func, d)
        srcdir = d.getVar('S', True)
        builddir = d.getVar('B', True)
        if srcdir != builddir:
            if os.path.exists(builddir):
                oe.path.copytree(builddir, os.path.join(srcdir, \
                    'build.%s.ar_configured' % d.getVar('PF', True)))
        create_tarball(d, srcdir, 'configured', ar_outdir)
}

def create_tarball(d, srcdir, suffix, ar_outdir, pf=None):
    """
    create the tarball from srcdir
    """
    import tarfile

    bb.utils.mkdirhier(ar_outdir)
    if pf:
        tarname = os.path.join(ar_outdir, '%s-%s.tar.gz' % (pf, suffix))
    else:
        tarname = os.path.join(ar_outdir, '%s-%s.tar.gz' % \
            (d.getVar('PF', True), suffix))

    srcdir = srcdir.rstrip('/')
    dirname = os.path.dirname(srcdir)
    basename = os.path.basename(srcdir)
    os.chdir(dirname)
    bb.note('Creating %s' % tarname)
    tar = tarfile.open(tarname, 'w:gz')
    tar.add(basename)
    tar.close()

# creating .diff.gz between source.orig and source
def create_diff_gz(d, src_orig, src, ar_outdir):

    import subprocess

    if not os.path.isdir(src) or not os.path.isdir(src_orig):
        return

    # The diff --exclude can't exclude the file with path, so we copy
    # the patched source, and remove the files that we'd like to
    # exclude.
    src_patched = src + '.patched'
    oe.path.copyhardlinktree(src, src_patched)
    for i in d.getVarFlag('ARCHIVER_MODE', 'diff-exclude', True).split():
        bb.utils.remove(os.path.join(src_orig, i), recurse=True)
        bb.utils.remove(os.path.join(src_patched, i), recurse=True)

    dirname = os.path.dirname(src)
    basename = os.path.basename(src)
    os.chdir(dirname)
    out_file = os.path.join(ar_outdir, '%s-diff.gz' % d.getVar('PF', True))
    diff_cmd = 'diff -Naur %s.orig %s.patched | gzip -c > %s' % (basename, basename, out_file)
    subprocess.call(diff_cmd, shell=True)
    bb.utils.remove(src_patched, recurse=True)

# Run do_unpack and do_patch
python do_unpack_and_patch() {
    if d.getVarFlag('ARCHIVER_MODE', 'src', True) not in \
            [ 'patched', 'configured'] and \
            d.getVarFlag('ARCHIVER_MODE', 'diff', True) != '1':
        return

    ar_outdir = d.getVar('ARCHIVER_OUTDIR', True)

    # Change the WORKDIR to make do_unpack do_patch run in another dir.
    d.setVar('WORKDIR', d.getVar('ARCHIVER_WORKDIR', True))

    # The changed 'WORKDIR' also casued 'B' changed, create dir 'B' for the
    # possibly requiring of the following tasks (such as some recipes's
    # do_patch required 'B' existed).
    bb.utils.mkdirhier(d.getVar('B', True))

    # The kernel source is ready after do_validate_branches
    if bb.data.inherits_class('kernel-yocto', d):
        bb.build.exec_func('do_unpack', d)
        bb.build.exec_func('do_kernel_checkout', d)
        bb.build.exec_func('do_validate_branches', d)
    else:
        bb.build.exec_func('do_unpack', d)

    # Save the original source for creating the patches
    if d.getVarFlag('ARCHIVER_MODE', 'diff', True) == '1':
        src = d.getVar('S', True).rstrip('/')
        src_orig = '%s.orig' % src
        oe.path.copytree(src, src_orig)
    bb.build.exec_func('do_patch', d)
    # Create the patches
    if d.getVarFlag('ARCHIVER_MODE', 'diff', True) == '1':
        bb.note('Creating diff gz...')
        create_diff_gz(d, src_orig, src, ar_outdir)
        bb.utils.remove(src_orig, recurse=True)
}

python do_ar_recipe () {
    """
    archive the recipe, including .bb and .inc.
    """
    import re
    import shutil

    require_re = re.compile( r"require\s+(.+)" )
    include_re = re.compile( r"include\s+(.+)" )
    bbfile = d.getVar('FILE', True)
    outdir = os.path.join(d.getVar('WORKDIR', True), \
            '%s-recipe' % d.getVar('PF', True))
    bb.utils.mkdirhier(outdir)
    shutil.copy(bbfile, outdir)

    dirname = os.path.dirname(bbfile)
    bbpath = '%s:%s' % (dirname, d.getVar('BBPATH', True))
    f = open(bbfile, 'r')
    for line in f.readlines():
        incfile = None
        if require_re.match(line):
            incfile = require_re.match(line).group(1)
        elif include_re.match(line):
            incfile = include_re.match(line).group(1)
        if incfile:
            incfile = bb.data.expand(incfile, d)
            incfile = bb.utils.which(bbpath, incfile)
            if incfile:
                shutil.copy(incfile, outdir)

    create_tarball(d, outdir, 'recipe', d.getVar('ARCHIVER_OUTDIR', True))
    bb.utils.remove(outdir, recurse=True)
}

python do_dumpdata () {
    """
    dump environment data to ${PF}-showdata.dump
    """

    dumpfile = os.path.join(d.getVar('ARCHIVER_OUTDIR', True), \
        '%s-showdata.dump' % d.getVar('PF', True))
    bb.note('Dumping metadata into %s' % dumpfile)
    f = open(dumpfile, 'w')
    # emit variables and shell functions
    bb.data.emit_env(f, d, True)
    # emit the metadata which isn't valid shell
    for e in d.keys():
        if bb.data.getVarFlag(e, 'python', d):
            f.write("\npython %s () {\n%s}\n" % (e, bb.data.getVar(e, d, True)))
    f.close()
}

SSTATETASKS += "do_deploy_archives"
do_deploy_archives () {
    echo "Deploying source archive files ..."
}
python do_deploy_archives_setscene () {
    sstate_setscene(d)
}
do_deploy_archives[sstate-inputdirs] = "${ARCHIVER_TOPDIR}"
do_deploy_archives[sstate-outputdirs] = "${DEPLOY_DIR_SRC}"

addtask do_ar_original after do_unpack
addtask do_unpack_and_patch after do_patch
addtask do_ar_patched after do_unpack_and_patch
addtask do_ar_configured after do_unpack_and_patch
addtask do_dumpdata
addtask do_ar_recipe
addtask do_deploy_archives before do_build
