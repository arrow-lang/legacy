# -*- coding: utf-8 -*-
import sys
import ws.test
import ws.snapshot
import waflib.Scripting
from os import path
import shutil
from subprocess import Popen, PIPE, check_output
from glob import glob


top = '.'
out = 'build'

SNAPSHOT_VERSION = "0.1.1"


def distclean(ctx):
    try:
        # Wipe the `.cache` dir.
        shutil.rmtree(path.join(top, ".cache"))

    except:
        # I think this is the point.
        pass

    # Clean the rest of the files.
    waflib.Scripting.distclean(ctx)


def options(ctx):
    # Add an option to specify an existing arrow compiler for the boostrap
    # process.
    ctx.add_option("--with-arrow", action='store', dest='arrow')

    # Add a --with-llvm-config option to specify what binary to use here
    # instead of the standard `llvm-config`.
    ctx.add_option(
        '--with-llvm-config', action='store', default='llvm-config',
        dest='llvm_config')

    # Add a --quick / -q option (for quick building)
    ctx.add_option("-q", action="store_true", default=False,
                   dest="quick_build")


def llvm_config(ctx, *args):
    command = [ctx.env.LLVM_CONFIG[0]]
    command.extend(args)
    return check_output(command).decode("utf-8").strip()


def configure(ctx):
    # Load preconfigured tools.
    ctx.load('c_config')

    # Ensure that we receive a path to an existing arrow compiler.
    if not ctx.options.arrow:
        # Attempt to get a snapshot for this platform.
        try:
            ctx.env.ARROW_SNAPSHOT = ws.snapshot.get_snapshot(SNAPSHOT_VERSION)

        except ws.snapshot.SnapshotNotFound:
            ctx.fatal("An existing arrow compiler is needed for the "
                      "boostrap process; specify one with \"--with-arrow\"")
    else:
        ctx.env.ARROW_SNAPSHOT = ctx.options.arrow

    # Report the compiler to be used.
    ctx.msg("Checking for 'arrow' (Arrow compiler)", ctx.env.ARROW_SNAPSHOT)

    # Check for the llvm compiler.
    ctx.find_program('llc', var='LLC')
    ctx.find_program('lli', var='LLI')
    ctx.find_program('opt', var='OPT')

    # Check for gcc.
    # NOTE: We only depend on this for the linking phase.
    ctx.find_program('gcc', var='GCC')
    ctx.find_program('g++', var='GXX')

    # Check for the `llvm-config`.
    ctx.find_program('llvm-config', var="LLVM_CONFIG")

    # Use `llvm-config` to discover configuration
    ctx.env.LLVM_LDFLAGS = llvm_config(ctx, "--ldflags")
    ctx.env.LLVM_LIBS = llvm_config(ctx, "--libs", "all")

    # Store addl. options
    ctx.env.QUICK_BUILD = ctx.options.quick_build


def _link(ctx, source, target, name):
    libs = ctx.env.LLVM_LIBS
    ldflags = ctx.env.LLVM_LDFLAGS
    ctx(rule="${GXX} -o${TGT} ${SRC} %s %s" % (libs, ldflags),
        source=source,
        target=target,
        name=name)


def build(ctx):

    # Build the stage-0 compiler from the fetched snapshot
    # Compile the compiler from llvm IL into native object code.
    ctx(rule="${LLC} -filetype=obj -o=${TGT} ${ARROW_SNAPSHOT}",
        target="stage0/arrow.o")

    # Link the compiler into a final executable.
    _link(ctx, "stage0/arrow.o", "stage0/arrow", "stage0")

    # Take the stage-1 compiler (the one that we have through
    # reasons unknown to us). Use this to compile the stage-2 compiler.

    # Compile the compiler to the llvm IL.
    ctx(rule="./stage0/arrow -L ../src ${SRC} | ${OPT} -O3 -o=${TGT}",
        source="src/compiler.as",
        target="stage1/arrow.ll",
        after="stage0")

    # Compile the compiler from llvm IL into native object code.
    ctx(rule="${LLC} -filetype=obj -o=${TGT} ${SRC}",
        source="stage1/arrow.ll",
        target="stage1/arrow.o")

    # Link the compiler into a final executable.
    _link(ctx, "stage1/arrow.o", "stage1/arrow", "stage1")

    if ctx.env.QUICK_BUILD:
        # Copy the stage1 compiler to "build/arrow"
        ctx(rule="cp ${SRC} ${TGT}",
            source="stage1/arrow",
            target="arrow")

        return

    # Use the newly compiled stage-1 to compile the stage-2 compiler

    # Compile the compiler to the llvm IL.
    ctx(rule="./stage1/arrow -L ../src ${SRC} | ${OPT} -O3 -o=${TGT}",
        source="src/compiler.as",
        target="stage2/arrow.ll",
        after="stage1")

    # Compile the compiler from llvm IL into native object code.
    ctx(rule="${LLC} -filetype=obj -o=${TGT} ${SRC}",
        source="stage2/arrow.ll",
        target="stage2/arrow.o")

    # Link the compiler into a final executable.
    _link(ctx, "stage2/arrow.o", "stage2/arrow", "stage2")

    # TODO: Run the test suite on the stage-3 compiler

    # TODO: Do a bit-by-bit equality check on both compilers

    # Copy the stage2 compiler to "build/arrow"
    ctx(rule="cp ${SRC} ${TGT}",
        source="stage2/arrow",
        target="arrow")


def test(ctx):
    print(ws.test._sep("test session starts", "="))
    print(ws.test._sep("tokenize", "-"))
    ws.test._test_tokenizer(ctx)
    print(ws.test._sep("parse", "-"))
    ws.test._test_parser(ctx)
    print(ws.test._sep("parse-fail", "-"))
    ws.test._test_parser_fail(ctx)
    print(ws.test._sep("run", "-"))
    ws.test._test_run(ctx)
    print(ws.test._sep("run-fail", "-"))
    ws.test._test_run_fail(ctx)
    ws.test._print_report()


def _test_tokenize(ctx):
    print(ws.test._sep("test session starts", "="))
    print(ws.test._sep("tokenize", "-"))
    ws.test._test_tokenizer(ctx)
    print(ws.test._sep("tokenize-fail", "-"))
    ws.test._test_tokenizer_fail(ctx)
    ws.test._print_report()

globals()["test:tokenize"] = _test_tokenize

def _test_parse(ctx):
    print(ws.test._sep("test session starts", "="))
    print(ws.test._sep("parse", "-"))
    ws.test._test_parser(ctx)
    print(ws.test._sep("parse-fail", "-"))
    ws.test._test_parser_fail(ctx)
    ws.test._print_report()

globals()["test:parse"] = _test_parse

def _test_run(ctx):
    print(ws.test._sep("test session starts", "="))
    print(ws.test._sep("run", "-"))
    ws.test._test_run(ctx)
    print(ws.test._sep("run-fail", "-"))
    ws.test._test_run_fail(ctx)
    ws.test._print_report()

globals()["test:run"] = _test_run
