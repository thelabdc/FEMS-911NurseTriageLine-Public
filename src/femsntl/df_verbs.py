"""
A file that contains some extra verbs for interacting with data frames
"""
from typing import List

import numpy as np
import pandas as pd


def case_when(*args) -> np.ndarray:
    """
    Perform an if/elif/else for a series of arguments that behave like
    a numpy array. This is the transpose of np.select.

    Note: If args as odd length, then the _final_ value is the default.
    Otherwise, it is 0.

    Example::
        case_when(
            np.arange(5) % 2 == 0, "Even",
            np.arange(5) % 3 == 0, "Multiple of 3",
            "Coprime to 6"
        )
        # returns np.array(["Even", "Coprime to 6", "Even", "Multiple of 3", "Even"])
    """
    even_out_len = (len(args) // 2) * 2
    return np.select(
        args[:even_out_len:2],
        args[1:even_out_len:2],
        default=args[-1] if len(args) % 2 == 1 else 0,
    )


def cross_join(left_df: pd.DataFrame, right_df: pd.DataFrame) -> pd.DataFrame:
    """
    Perform a CROSS JOIN between `left_df` and `right_df`.

    Args:
        left_df: The left hand data frame to cross join
        right_df: The right hand data frame to cross join
    """
    # Some modifications need to be made to the data frames, so we make copies
    left_df = left_df.copy()
    right_df = right_df.copy()

    key = "key"
    while key in left_df or key in right_df:
        key += "key"

    left_df[key] = 0
    right_df[key] = 0

    return left_df.merge(right_df, how="outer", on=key).drop(key, axis=1)


def find_ids(df: pd.DataFrame, id_var: str, subset_var: str) -> List[str]:
    """
    Return the unique values in the `id_var` column in
    rows where `subset_var` is non-null.

    Args:
        df: The data frame to examine
        id_var: The values to return
        subset_var: The rows to subset where the row is non-null

    Returns:
        The unique values where subset_var is non-null
    """
    return df.loc[df[subset_var].notna(), id_var].unique()


def append_max_and_count(
    df: pd.DataFrame,
    id_col: str = "name_dob_id",
    value_col: str = "match_points",
    inplace: bool = True,
) -> pd.DataFrame:
    """
    Given a DataFrame, add two columns:
        * f'max_{value_col}' which, for each group determined by `id_col`,
          is the maximum value in the group, and
        * f'count_of_{value_col}', which, for each [`id_col`, `value_col`] pair
          is the number of times that pair appears

    If `inplace` is True, then edit the data frame in place
    """
    df = df if inplace else df.copy()

    df[f"max_{value_col}"] = df.groupby(id_col)[value_col].transform("max")
    df[f"count_of_{value_col}"] = df.groupby([id_col, value_col])[value_col].transform(
        "count"
    )
    return df
