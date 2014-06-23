# -*- coding: utf-8 -*-
import sys
import ws.test
import ws.snapshot
import waflib.Scripting
from os import path
import shutil
from subprocess import Popen, PIPE
from glob import glob

top = '.'
out = 'build'

def distclean(ctx):
    try:
        # Wipe the `.cache` dir.
        shutil.rmtree(path.join(top, ".cache"))

    except FileNotFoundError:
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

def configure(ctx):
    # Load preconfigured tools.
    ctx.load('c_config')

    # Ensure that we receive a path to an existing arrow compiler.
    if not ctx.options.arrow:
        # Attempt to get a snapshot for this platform.
        try:
            ctx.env.ARROW = ws.snapshot.get_snapshot("0.0.0")

        except ws.snapshot.SnapshotNotFound:
            ctx.fatal("An existing arrow compiler is needed for the "
                      "boostrap process; specify one with \"--with-arrow\"")
    else:
        ctx.env.ARROW = ctx.options.arrow

    # Report the compiler to be used.
    ctx.msg("Checking for 'arrow' (Arrow compiler)", ctx.env.ARROW)

    # Check for the llvm compiler.
    ctx.find_program('llc', var='LLC')
    ctx.find_program('lli', var='LLI')
    ctx.find_program('opt', var='OPT')

    # Check for gcc.
    # NOTE: We only depend on this for the linking phase.
    ctx.find_program('gcc', var='GCC')
    ctx.find_program('g++', var='GXX')

    # Check for the LLVM libraries.
    ctx.check_cfg(path=ctx.options.llvm_config, package='',
                  args='--ldflags --libs all', uselib_store='LLVM')

def build(ctx):
    # Compile the compiler to the llvm IL.
    ctx(rule="${ARROW} -w --no-prelude -L ../src -S ${SRC} > ${TGT}",
        source="src/compiler.as",
        target="compiler.ll")

    # Optimize the compiler.
    ctx(rule="${OPT} -O3 -o=${TGT} ${SRC}",
        source="compiler.ll",
        target="compiler.opt.ll")

    # Compile the compiler from llvm IL into native object code.
    ctx(rule="${LLC} -filetype=obj -o=${TGT} ${SRC}",
        source="compiler.opt.ll",
        target="compiler.o")

    # Link the compiler into a final executable.
    libs = " ".join(map(lambda x: "-l%s" % x, ctx.env['LIB_LLVM']))
    ctx(rule="${GXX} -o${TGT} ${SRC} %s" % libs,
        source="compiler.o",
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
