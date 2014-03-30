# -*- coding: utf-8 -*-
import sys
from os import path
from subprocess import Popen, PIPE
from glob import glob

top = '.'
out = 'build'

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
        ctx.fatal("An existing arrow compiler is needed for the "
                  "boostrap process; specify one with \"--with-arrow\"")

    # Report the compiler to be used.
    ctx.env.ARROW = ctx.options.arrow
    ctx.msg("Checking for 'arrow' (Arrow compiler)", ctx.env.ARROW)

    # Check for the llvm compiler.
    ctx.find_program('llc', var='LLC')
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

    # Compile the generator to the llvm IL.
    ctx(rule="${ARROW} -w --no-prelude -L ../src -S ${SRC} > ${TGT}",
        source="src/generator.as",
        target="generator.ll")

    # Optimize the generator.
    ctx(rule="${OPT} -O3 -o=${TGT} ${SRC}",
        source="generator.ll",
        target="generator.opt.ll")

    # Compile the generator from llvm IL into native object code.
    ctx(rule="${LLC} -filetype=obj -o=${TGT} ${SRC}",
        source="generator.opt.ll",
        target="generator.o")

    # Link the generator into a final executable.
    libs = " ".join(map(lambda x: "-l%s" % x, ctx.env['LIB_LLVM']))
    ctx(rule="${GXX} -o${TGT} ${SRC} %s" % libs,
        source="generator.o",
        target="generator")

def _run(filename, command, options):
    with open(filename) as stream:
        # Execute and run the test case.
        p = Popen([path.join(out, command)] + options,
                  stdin=stream, stdout=PIPE, stderr=PIPE)
        stdout, stderr = p.communicate()
        return p.returncode, stdout, stderr

def _read_suffix(filename, suffix):
    try:
        with open(path.splitext(filename)[0] + suffix, 'rb') as stream:
            return stream.read()

    except:
        return None

def _check_expected_stdout(filename, stdout):
    expected = _read_suffix(filename, ".out")
    if stdout == b'' and expected == None:
        return True

    return expected == stdout

def _check_expected_stderr(filename, stderr):
    expected = _read_suffix(filename, ".err")
    if stderr == b'' and expected == None:
        return True

    return expected == stderr

_passed = 0
_failed = 0

def _report(filename, status):
    global _passed
    global _failed
    filename = path.relpath(filename)
    if not status:
        _failed += 1
        print("\033[31m{:<72}: {}\033[0m".format(filename, 'FAIL'))

    else:
        _passed += 1
        print("{:<72}: \033[32m{}\033[0m".format(filename, 'PASS'))

def _test_tokenizer(ctx):
    # Enumerate through the test directory and run the command sequence,
    # checking against the expected output.
    for fixture in glob("tests/tokenize/*.as"):
        # Run the tokenizer over our fixture.
        returncode, stdout, stderr = _run(fixture, 'tokenizer', [])

        # Check the output against the expected.
        # FIXME: Check the returncode
        status = True
        # status = returncode == 0
        status = status and _check_expected_stdout(fixture, stdout)

        # Report our status.
        _report(fixture, status)

def _test_parser(ctx):
    # Enumerate through the test directory and run the command sequence,
    # checking against the expected output.
    for fixture in glob("tests/parse/*.as"):
        # Run the parser over our fixture.
        returncode, stdout, stderr = _run(fixture, 'parser', [])

        # Check the output against the expected.
        status = True
        status = returncode == 0
        status = status and _check_expected_stdout(fixture, stdout)

        # Report our status.
        _report(fixture, status)

def _test_parser_fail(ctx):
    # Enumerate through the test directory and run the command sequence,
    # checking against the expected output.
    for fixture in glob("tests/parse-fail/*.as"):
        # Run the parser over our fixture.
        returncode, stdout, stderr = _run(fixture, 'parser', [])

        # Check the output against the expected.
        status = True
        status = returncode == 255
        status = status and _check_expected_stderr(fixture, stderr)

        # Report our status.
        _report(fixture, status)

def _print_report():
    print()

    message = "{} passed".format(_passed)
    if _failed:
        message += ", {} failed".format(_failed)

    if not _failed:
        sys.stdout.write("\033[1;32m")
        print(_sep(message))
        sys.stdout.write("\033[0m")
    else:
        sys.stdout.write("\033[1;31m")
        print(_sep(message))
        sys.stdout.write("\033[0m")

def _sep(text, char="=", size=80):
    size -= len(text) + 2
    left = right = size // 2
    if size % 2 != 0:
        right += 1
    return (char * left) + " " + text + " " + (char * right)

def test(ctx):
    print(_sep("test session starts", "="))
    print(_sep("tokenize", "-"))
    _test_tokenizer(ctx)
    print(_sep("parse", "-"))
    _test_parser(ctx)
    print(_sep("parse-fail", "-"))
    _test_parser_fail(ctx)
    _print_report()
