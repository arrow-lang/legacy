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

def configure(ctx):
    # Ensure that we receive a path to an existing arrow compiler.
    if not ctx.options.arrow:
        ctx.fatal("An existing arrow compiler is needed for the "
                  "boostrap process; specify one with \"--with-arrow\"")

    # Report the compiler to be used.
    ctx.env.ARROW = ctx.options.arrow
    ctx.msg("Checking for 'arrow' (Arrow compiler)", ctx.env.ARROW)

    # Check for the llvm compiler.
    ctx.find_program('llc', var='LLC')

    # Check for gcc.
    # NOTE: We only depend on this for the linking phase.
    ctx.find_program('gcc', var='GCC')

def build(ctx):
    # Compile the tokenizier to the llvm IL.
    ctx(rule="${ARROW} -w --no-prelude -L ../src -S ${SRC} > ${TGT}",
        source="src/tokenizer.as",
        target="tokenizer.ll")

    # Compile the tokenizier from llvm IL into native object code.
    ctx(rule="${LLC} -filetype=obj -o=${TGT} ${SRC}",
        source="tokenizer.ll",
        target="tokenizer.o")

    # Link the tokenizier into a final executable.
    ctx(rule="${GCC} -o${TGT} ${SRC}",
        source="tokenizer.o",
        target="tokenizer")

def _run(filename, commands):
    with open(filename) as stream:
        # Execute and run the test case.
        p = Popen([path.join(out, 'tokenizer')] + commands,
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

def _report(filename, status):
    filename = path.relpath(filename)
    if not status:
        print("\033[31m{:<50}: {}\033[0m".format(filename, 'FAIL'))

    else:
        print("{:<50}: \033[32m{}\033[0m".format(filename, 'PASS'))

def _test_tokenizer(ctx):
    # Enumerate through the test directory and run the command sequence,
    # checking against the expected output.
    for fixture in glob("tests/tokenizer/*.as"):
        # Run the tokenizer over our fixture.
        returncode, stdout, stderr = _run(fixture, [])

        # Check the output against the expected.
        # FIXME: Check the returncode
        status = True
        # status = returncode == 0
        status = status and _check_expected_stdout(fixture, stdout)

        # Report our status.
        _report(fixture, status)

def _test_tokenizer_self(ctx):
    # Check the tokenizer against itself.
    returncode, stdout, stderr = _run("src/tokenizer.as", [])

    # Check the output against the expected.
    # FIXME: Check the returncode
    status = True
    # status = returncode == 0
    status = status and _check_expected_stdout(
        "tests/tokenizer/tokenizer.as", stdout)

    # Report our status.
    _report("src/tokenizer.as", status)

def test(ctx):
    _test_tokenizer(ctx)
    _test_tokenizer_self(ctx)
