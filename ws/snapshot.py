import os
import zipfile
from os import path
from subprocess import check_call
from urllib.request import urlopen, HTTPError
import platform
import tarfile


class SnapshotNotFound(BaseException):
    pass


SOURCE = "https://www.dropbox.com/sh/fdpdlrprph7yh6t/p-Vy2gNkrI/arrow-lang/releases/arrow-{version}/{target}?dl=1"


def get_target():
    machine = platform.machine()
    system = platform.system().lower()

    return "%s-%s" % (machine, system)


def get_snapshot(version, target=None):
    # Determine the snapshot cache folder.
    base_dir = path.dirname(path.dirname(__file__))
    cache_dir = path.join(base_dir, ".cache/snapshots/%s" % version)
    target = target or get_target()
    snapshot_dir = path.join(cache_dir, target)

    # Create the neccessary directories.
    os.makedirs(snapshot_dir, exist_ok=True)

    # Check for an existing snapshot.
    snapshot_zipfile = path.join(cache_dir, "%s.zip" % target)
    if not path.exists(snapshot_zipfile):
        # Build the URI
        uri = SOURCE.format(version=version, target=target)

        # Fetch the zip file and store
        with open(snapshot_zipfile, "wb") as stream:
            try:
                stream.write(urlopen(uri).read())
                print("\033[0;33mDownloaded arrow from %s\033[0m" % uri)

            except HTTPError as ex:
                if ex.getcode() == 404:
                    # No snapshot available.
                    raise SnapshotNotFound

        # Unzip the snapshot file.
        with zipfile.ZipFile(snapshot_zipfile, "r") as handle:
            handle.extractall(cache_dir)

        # Untar the snapshot.
        snapshot_tarfile = path.join(
            snapshot_dir, "arrow-%s-%s.tar.xz" % (version, target))
        with tarfile.open(snapshot_tarfile) as handle:
            handle.extractall(snapshot_dir)

    # Return the compiler path.
    return path.join(snapshot_dir, "bin/arrow")
