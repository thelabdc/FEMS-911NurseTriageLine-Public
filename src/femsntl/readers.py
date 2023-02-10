from pathlib import Path
from typing import List, Tuple, Union

import pandas as pd


def read_file(
    filename: Union[str, Path],
    str_columns: Union[Tuple[str, ...], List[str]] = ("MedicaidSystemID",),
) -> pd.DataFrame:
    """
    Read a file into pandas if it is either a CSV or Excel file. If any of the
    names in str_columns are present, convert those columns into string types.
    """
    filename = Path(filename)
    str_columns = str_columns or []

    if filename.suffix == ".csv":
        df = pd.read_csv(filename)
    elif filename.suffix[:4] == ".xls":
        df = pd.read_excel(filename)

    for col in str_columns:
        if col in df.columns:
            df[col] = df[col].astype(str)

    return df
