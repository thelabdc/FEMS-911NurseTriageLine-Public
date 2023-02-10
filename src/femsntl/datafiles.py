from pathlib import Path
from typing import Iterable, List, Optional

ROOT_MARKERS = (
    ".git",
    "pyproject.toml",
    "poetry.lock",
)


def here(*name: str, root_markers: Optional[Iterable[str]] = None) -> Path:
    """
    Mimic the utility of R's `here` function which allows you to specify the location
    of a directory relative to a project's root folder. We look up from the current
    working directory to see if the directory contains a file called one of the
    `root_markers` and then return the Path which is that directory concatenated with
    passed `name`.

    If no `root_markers` are passed, then the default ROOT_MARKERS are used.

    Args:
        name: The subpath to specify relative to the project root
        root_markers: The filenames that indicate a project root

    Returns:
        The Path `name` relative to the project root

    Raises:
        ValueError: If project root cannot be found
    """
    root_markers = root_markers or ROOT_MARKERS
    path = Path.cwd()
    while True:
        if any((path / marker).exists() for marker in root_markers):
            return path / Path(*name)
        if path.parent == path:
            raise ValueError(f"No project root found relative to cwd: {Path.cwd()}")
        path = path.parent


BASE_DIR = here()
DATA_DIR = BASE_DIR / "data"
SRC_DIR = BASE_DIR / "src"
TEST_DIR = BASE_DIR / "tests"
NOTEBOOK_DIR = BASE_DIR / "src" / "notebooks"
PRIVATE_DATA_DIR = DATA_DIR / "private_data"
PUBLIC_DATA_DIR = DATA_DIR / "public_data"
EXTERNAL_DIR = DATA_DIR / "data_shared_externally"
INTERMEDIATE_DIR = DATA_DIR / "intermediate_objects"
OUTPUT_DIR = BASE_DIR / "output"
SAFETYPAD_DIR = PRIVATE_DATA_DIR / "safetypad"

CREDENTIALS_FILE = BASE_DIR / "creds.yml"

EMS_EVENTS_2016 = PUBLIC_DATA_DIR / "2016_EMS_Events.csv.gz"

SQL_DUMP_FILE = PRIVATE_DATA_DIR / "ntl_sql_dump.parquet"
PKL_FILE = PRIVATE_DATA_DIR / "ntl_summary_raw.pkl"

NTL_START_DATE = "2018-03-19"
NTL_END_DATE = "2019-03-01"
