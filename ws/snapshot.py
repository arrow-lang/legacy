import os
import zipfile
from os import path
from subprocess import check_call
import platform
import tarfile

try:
    from urllib.request import urlopen, HTTPError

except ImportError:
    from urllib2 import urlopen, HTTPError


class SnapshotNotFound(BaseException):
    pass


SOURCE = "https://dl.dropboxusercontent.com/u/19497679/arrow-lang/releases/arrow-{version}/{target}/arrow-{version}-{target}.tar.gz"


def get_target():
    machine = platform.machine()
    system = platform.system().lower()

    return "%s-%s" % (machine, system)


def get_snapshot(version, target=None):
    # Determine the snapshot cache folder.
    base_dir = path.dirname(path.dirname(__file__))
    cache_dir = path.join(base_dir, ".cache/snapshots")
    target = target or get_target()
    snapshot_dir = cache_dir

    try:
        # Create the neccessary directories.
        os.makedirs(snapshot_dir)

    except:
        # If it failed, oh well
        pass

    # Check for an existing snapshot.
    snapshot_file = path.join(cache_dir, "arrow-%s-%s/bin/arrow.ll" % (
                              version, target))
    if path.exists(snapshot_file):
        return snapshot_file

    # Keep going
    snapshot_tarfile = path.join(cache_dir, "arrow-%s-%s.tar.gz" % (version, target))
    if not path.exists(snapshot_tarfile):
        # Build the URI
        uri = SOURCE.format(version=version, target=target)

        # Fetch the zip file and store
        with open(snapshot_tarfile, "wb") as stream:
            try:
                stream.write(urlopen(uri).read())
                print("\033[0;33mDownloaded arrow from %s\033[0m" % uri)

            except HTTPError as ex:
                if ex.getcode() == 404:
                    # No snapshot available.
                    raise SnapshotNotFound

    # Untar the snapshot.
    if not path.exists(snapshot_file):
        with tarfile.open(snapshot_tarfile) as handle:
            handle.extractall(snapshot_dir)

    # Return the compiler path.
    return snapshot_file
