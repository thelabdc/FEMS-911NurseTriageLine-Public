import tempfile
from pathlib import Path

import numpy as np
import pandas as pd
import pytest

from femsntl.utils import (
    clean_amr_names,
    clean_column_names,
    compute_sha,
    extract_DOB_fromname,
    get_mostrec,
    process_safetypad_names,
    standardize_month,
    standardize_year,
)


@pytest.fixture(scope="module")
def fixtures_path() -> Path:
    """ The location of any fixtures for tests """
    return Path(__file__).parent / "fixtures"


def test_compute_sha(fixtures_path: Path):
    # Computed with the gnu util sha256sum
    expected = "af148712ad31b5994a364a78405ecb58fa40c6275bfe814bb08a7b7be779fe9e"
    assert compute_sha(fixtures_path / "small_text_file.txt") == expected


def test_clean_column_names():
    assert clean_column_names(["AB**c83-_fs", "---hello   goodbye "]) == [
        "abc83_fs",
        "hello_goodbye",
    ]


def test_process_safetypad_names():
    assert process_safetypad_names("hello") == "hello"
    assert process_safetypad_names([]) is None
    assert process_safetypad_names(("a", "b", "c")) == "a; b; c"


def test_extract_DOB_fromname():
    assert extract_DOB_fromname("foo 33 bar / 30/10 ///") == "33/30/10///"


def test_clean_amr_names():
    assert clean_amr_names("kevin") == "KEVIN"
    assert clean_amr_names("Kevin 1/1/92") == "KEVIN"
    assert clean_amr_names("KEVIN UNK 1/1/92     WILSON") == "KEVIN UNK WILSON"
    assert clean_amr_names("KEVIN   UNK 1/1/92 WILSON", ["UNK"]) == "KEVIN WILSON"

    assert clean_amr_names(None) is None
    assert clean_amr_names(np.nan) is None
    assert clean_amr_names(pd.NA) is None


def test_standardize_year():
    assert standardize_year(None) is None
    assert standardize_year("1") is None
    assert standardize_year("20") == "1920"
    assert standardize_year("123") is None
    assert standardize_year("2020") == "2020"
    assert standardize_year("20202") == "2020"


def test_standardize_month():
    assert standardize_month(None) is None
    assert standardize_month("1") == "01"
    assert standardize_month("10") == "10"
    assert standardize_month("101") is None


def test_get_mostrec():
    with tempfile.TemporaryDirectory() as tmpdir:
        tempdir = Path(tmpdir)
        with open(tempdir / "foo-2021-01-01.csv", "wt") as outfile:
            outfile.write("hold")
        with open(tempdir / "foo-2021-01-02.csv", "wt") as outfile:
            outfile.write("hold2")
        with open(tempdir / "bar-2021-01-03.csv", "wt") as outfile:
            outfile.write("hold2")

        assert (
            get_mostrec("foo", tempdir) == (tempdir / "foo-2021-01-02.csv").absolute()
        )
        assert (
            get_mostrec("bar", tempdir) == (tempdir / "bar-2021-01-03.csv").absolute()
        )
        with pytest.raises(ValueError):
            get_mostrec("baz", tempdir)
