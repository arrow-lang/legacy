# -*- coding: utf-8 -*-
import sys
from os import path
from subprocess import Popen, PIPE
import io
from glob import glob

out = path.join(path.dirname(__file__), '../build')

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
_xfailed = 0
_xpassed = 0

def _report(filename, status):
    global _passed
    global _failed
    global _xfailed
    global _xpassed

    # Check if we are "expected" to fail
    xfail = _read_suffix(filename, ".xfail") is not None

    filename = path.relpath(filename)
    if not status:
        if xfail:
            _xfailed += 1
            print("\033[30;1m{:<72}: {}\033[0m".format(filename, 'XFAIL'))
        else:
            _failed += 1
            print("\033[31m{:<72}: {}\033[0m".format(filename, 'FAIL'))

    else:
        if xfail:
            _xpassed += 1
            print("\033[31m{:<72}: {}\033[0m".format(filename, 'XPASS'))
        else:
            _passed += 1
            print("{:<72}: \033[32m{}\033[0m".format(filename, 'PASS'))

def _test_tokenizer(ctx):
    for fixture in sorted(glob("tests/tokenize/*.as")):
        # Run the tokenizer over our fixture.
        returncode, stdout, stderr = _run(fixture, 'tokenizer', [])

        # Check the output against the expected.
        # FIXME: Check the returncode
        status = True
        # status = returncode == 0
        status = status and _check_expected_stdout(fixture, stdout)

        # Report our status.
        _report(fixture, status)

def _test_tokenizer_fail(ctx):
    for fixture in sorted(glob("tests/tokenize-fail/*.as")):
        # Run the tokenizer over our fixture.
        returncode, stdout, stderr = _run(fixture, 'tokenizer', [])

        # Check the output against the expected.
        status = True
        status = returncode == 255
        status = status and _check_expected_stderr(fixture, stderr)

        # Report our status.
        _report(fixture, status)

def _test_parser(ctx):
    for fixture in sorted(glob("tests/parse/*.as")):
        # Run the parser over our fixture.
        returncode, stdout, stderr = _run(fixture, 'parser', [])

        # Check the output against the expected.
        status = True
        status = returncode == 0
        status = status and _check_expected_stdout(fixture, stdout)

        # Report our status.
        _report(fixture, status)

def _test_parser_fail(ctx):
    for fixture in sorted(glob("tests/parse-fail/*.as")):
        # Run the parser over our fixture.
        returncode, stdout, stderr = _run(fixture, 'parser', [])

        # Check the output against the expected.
        status = True
        status = returncode == 255
        status = status and _check_expected_stderr(fixture, stderr)

        # Report our status.
        _report(fixture, status)

def _test_run(ctx):
    for fixture in sorted(glob("tests/run/*.as")):
        # Run the generator over our fixture.
        with open(fixture) as stream:
            # Execute and run the test case.
            p = Popen([path.join(out, 'generator')],
                      stdin=stream, stdout=PIPE, stderr=PIPE)
            p2 = Popen(["lli"], stdin=p.stdout, stdout=PIPE, stderr=PIPE)
            stdout, stderr = p2.communicate()

            # Read in the expected return code.
            expected = _read_suffix(fixture, ".returncode")
            returncode = 0
            if expected:
                returncode = int(expected)

            # Check the output against the expected.
            status = True
            status = p2.returncode == returncode
            status = status and _check_expected_stdout(fixture, stdout)

            # Report our status.
            _report(fixture, status)

def _test_run_fail(ctx):
    for fixture in sorted(glob("tests/run-fail/*.as")):
        # Run the generator over our fixture.
        with open(fixture) as stream:
            # Execute and run the test case.
            p = Popen([path.join(out, 'generator')],
                      stdin=stream, stdout=PIPE, stderr=PIPE)
            stdout, stderr = p.communicate()

            # Check the output against the expected.
            status = True
            status = p.returncode == 255
            status = status and _check_expected_stderr(fixture, stderr)

            # Report our status.
            _report(fixture, status)

def _print_report():
    print()

    message = []
    if _passed:
        message.append("{} passed".format(_passed))
    if _failed:
        message.append("{} failed".format(_failed))
    if _xfailed:
        message.append("{} xfailed".format(_xfailed))
    if _xpassed:
        message.append("{} xpassed".format(_xpassed))

    message = ', '.join(message)

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
