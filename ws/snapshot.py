from os import path
from subprocess import check_call
from urllib.request import urlopen
import platform

SOURCE = "https://www.dropbox.com/sh/fdpdlrprph7yh6t/p-Vy2gNkrI/arrow-lang/releases/arrow-{version}/{target}"

def get_target():
    machine = platform.machine()
    system = platform.system().lower()

    return "%s-%s" % (machine, system)

def get_snapshot(version, target=None):
    # Determine the snapshot cache folder.
    base_dir = path.dirname(path.dirname(__file__))
    cache_dir = path.join(base_dir, ".cache/snapshots")

    # Create the neccessary directories.
    os.makedirs(cache_dir, exist_ok=True)

    # Check for an existing snapshot.
    target = target or get_target()
    snapshot_dir = path.join(cache_dir, target)
    snapshot_file = path.join(snapshot_dir, "%s.tar.xz" % target)
    if path.exists(snapshot_dir):
        # TODO!

    else:
        # Build the URI
        uri = SOURCE.format(version=version, target=target)

        # Fetch the zip file and store
        with open(snapshot_file, "wb") as stream
            stream.write(urlopen(uri).read())
