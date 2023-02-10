import hashlib
import re
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Iterable, List, Optional, Union, cast

import pandas as pd

from .datafiles import INTERMEDIATE_DIR


@contextmanager
def _open_or_yield(filename: Optional[str] = None, mode: str = "rt"):
    if not filename or filename == "-":
        if "w" in mode:
            yield sys.stdout
        elif "r" in mode:
            yield sys.stdin
        else:
            raise ValueError(f"mode must contain w or r: {mode}")
    else:
        with open(filename, mode) as open_file:
            yield open_file


def compute_sha(filename: Union[str, Path]) -> str:
    sha = hashlib.sha256()
    with open(filename, "rb") as infile:
        while True:
            chunk = infile.read(8192)
            if not chunk:
                break
            sha.update(chunk)
    return sha.hexdigest()


def clean_column_names(column_names: List[str]) -> List[str]:
    """ Lower case, replace spaces with _, and remove all non-alphanumeric chars """
    return [
        re.sub(
            r"[^A-Za-z0-9_]",
            "",
            re.sub(r" +", "_", col.split(":", 1)[-1].strip().lower()),
        )
        for col in column_names
    ]


def longform_crosstab(crosstab: pd.DataFrame, grouping_var: str) -> pd.DataFrame:
    crosstab.columns = ["count_" + str(x) for x in crosstab.columns]
    crosstab[grouping_var] = crosstab.index
    crosstab_long = pd.melt(crosstab, id_vars=grouping_var)
    crosstab_long["date"] = pd.to_datetime(
        crosstab_long.variable.str.replace("count\\_", "", regex=True)
    )
    return crosstab_long


def process_safetypad_names(one_name: Union[str, Iterable[str]]) -> Optional[str]:
    """
    Process names from SafetyPAD. If a single name is passed, just return it.
    If an iterable of names is passed, return the elements of the list joined by '; ',
    unless the list is empty, in which case, return None

    Arguments:
        one_name: The (potentially list of) name(s) to process

    Returns:
        Either None or the name(s) as a single string
    """
    if isinstance(one_name, str):
        return one_name

    return "; ".join(one_name) or None


def extract_DOB_fromname(one_name: Optional[str]) -> Optional[str]:
    """
    In our data sets, a person's DOB is often included in the name field. We
    return a string containing all the digits and the character "/" from the
    passed one_name (unless it looks null, in which case we return None)

    Arguments:
        one_name: A single name

    Returns:
        The digits and any slashes as a string (or None if None is passed)
    """
    if pd.isna(one_name):
        return None

    one_name = cast(str, one_name)  # mypy doesn't recognize pd.isna
    return re.sub(r"[^0-9/]", "", one_name)


def clean_amr_names(
    one_name: str, non_names: Optional[Iterable[str]] = None
) -> Optional[str]:
    """
    Clean a name that comes from the AMR data. Specifically:
        * upper case it
        * remove all the `non_names` it contains
        * remove things that look like birthdates
        * remove extraneous whitespace

    Arguments:
        one_name: The name to clean
        non_names: Stings that are definitely not names

    Returns:
        The cleaned name (or None if `one_name` is null-like)
    """
    if pd.isna(one_name):
        return None

    # Capitalize
    one_name = one_name.upper()

    ## then, remove words that aren't names
    one_name = " ".join(
        [char for char in re.split("\W+", one_name) if char not in non_names]
    )

    # Remove things that look like birthdates
    one_name = re.sub(r"[0-9/]", "", one_name)

    # Remove extraneous whitespace
    one_name = re.sub(r" +", " ", one_name).strip()

    return one_name


def standardize_year(date: Optional[str]) -> Optional[str]:
    """
    Take a string that should be a year and attempt to turn it into a four-digit year

    Arguments:
        date: The string to (un)pad appropriately

    Returns:
        The four-digit year if possible. If not, returns None
    """
    if pd.isna(date):
        return None

    date = cast(str, date)
    if len(date) == 2:
        return f"19{date}"

    if len(date) >= 4:
        return date[:4]

    return None


def standardize_month(date: Optional[str]) -> Optional[str]:
    """
    Take a string that should be a month and attempt to turn it into a two-digit month

    Arguments:
        date: The string to (un)pad appropriately

    Returns:
        The two-digit month if possible. If not, returns None
    """
    if pd.isna(date):
        return None

    date = cast(str, date)
    if len(date) > 2:
        return None

    return f"{date:0>2s}"


def get_mostrec(prefix: str, base_dir: Union[Path, str] = INTERMEDIATE_DIR) -> Path:
    """
    Retrieve the most recent version of a file named "{prefix}-YYYY-MM-DD*" in base_dir

    Args:
        prefix: What name prefix does the file have?

    Returns:
        absolute path to the most recent version (defined in terms of last modified time)

    Raises:
        ValueError: No files of the given prefix in base_dir
    """
    return max(Path(base_dir).glob(f"{prefix}*")).absolute()
