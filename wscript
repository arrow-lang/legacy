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
    # Wipe the `.cache` dir.
    shutil.rmtree(path.join(top, ".cache"))

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
    # Compile the tokenizer to the llvm IL.
    ctx(rule="${ARROW} -w --no-prelude -L ../src -S ${SRC} > ${TGT}",
        source="src/tokenizer.as",
        target="tokenizer.ll")

    # Optimize the tokenizer.
    ctx(rule="${OPT} -O3 -o=${TGT} ${SRC}",
        source="tokenizer.ll",
        target="tokenizer.opt.ll")

    # Compile the tokenizer from llvm IL into native object code.
    ctx(rule="${LLC} -filetype=obj -o=${TGT} ${SRC}",
        source="tokenizer.opt.ll",
        target="tokenizer.o")

    # Link the tokenizer into a final executable.
    ctx(rule="${GCC} -o${TGT} ${SRC}",
        source="tokenizer.o",
        target="tokenizer")

    # Compile the parser to the llvm IL.
    ctx(rule="${ARROW} -w --no-prelude -L ../src -S ${SRC} > ${TGT}",
        source="src/parser.as",
        target="parser.ll")

    # Optimize the parser.
    ctx(rule="${OPT} -O3 -o=${TGT} ${SRC}",
        source="parser.ll",
        target="parser.opt.ll")

    # Compile the parser from llvm IL into native object code.
    ctx(rule="${LLC} -filetype=obj -o=${TGT} ${SRC}",
        source="parser.opt.ll",
        target="parser.o")

    # Link the parser into a final executable.
    ctx(rule="${GCC} -o${TGT} ${SRC}",
        source="parser.o",
        target="parser")

    # # Compile the generator to the llvm IL.
    # ctx(rule="${ARROW} -w --no-prelude -L ../src -S ${SRC} > ${TGT}",
    #     source="src/generator.as",
    #     target="generator.ll")

    # # Optimize the generator.
    # ctx(rule="${OPT} -O3 -o=${TGT} ${SRC}",
    #     source="generator.ll",
    #     target="generator.opt.ll")

    # # Compile the generator from llvm IL into native object code.
    # ctx(rule="${LLC} -filetype=obj -o=${TGT} ${SRC}",
    #     source="generator.opt.ll",
    #     target="generator.o")

    # # Link the generator into a final executable.
    # libs = " ".join(map(lambda x: "-l%s" % x, ctx.env['LIB_LLVM']))
    # ctx(rule="${GXX} -o${TGT} ${SRC} %s" % libs,
    #     source="generator.o",
    #     target="generator")

def test(ctx):
    print(ws.test._sep("test session starts", "="))
    print(ws.test._sep("tokenize", "-"))
    ws.test._test_tokenizer(ctx)
    print(ws.test._sep("parse", "-"))
    ws.test._test_parser(ctx)
    print(ws.test._sep("parse-fail", "-"))
    ws.test._test_parser_fail(ctx)
    # print(_sep("run", "-"))
    # _test_run(ctx)
    ws.test._print_report()
