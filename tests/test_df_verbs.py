import numpy as np
import pandas as pd

from femsntl import df_verbs


def test_case_when_odd():
    assert (
        df_verbs.case_when(
            np.arange(5) % 2 == 0,
            "Even",
            np.arange(5) % 3 == 0,
            "Multiple of 3",
            "Coprime to 6",
        )
        == np.array(["Even", "Coprime to 6", "Even", "Multiple of 3", "Even"])
    ).all()


def test_case_when_even():
    assert (
        df_verbs.case_when(np.arange(5) % 2 == 0, 2, np.arange(5) % 3 == 0, 3)
        == np.array([2, 0, 2, 3, 2])
    ).all()


def test_cross_join():
    # Whether or not the inplace flag is True, we should have the
    # same results
    left_df = pd.DataFrame({"a": [1, 2, 3]})
    right_df = pd.DataFrame({"b": [4, 5, 6]})

    expected_rows = {(left, right) for left in [1, 2, 3] for right in [4, 5, 6]}
    merged_df = df_verbs.cross_join(left_df, right_df)
    actual_rows = {(row.a, row.b) for _, row in merged_df.iterrows()}

    assert expected_rows == actual_rows

    assert len(left_df) == 3 and len(left_df.columns) == 1 and left_df.columns[0] == "a"
    assert (
        len(right_df) == 3 and len(right_df.columns) == 1 and right_df.columns[0] == "b"
    )


def test_find_ids():
    df = pd.DataFrame(
        {
            "id_var": [1, 2, 3, 4, 5],
            "subset_var_1": [11, 12, 13, pd.NA, 15],
            "subset_var_2": [pd.NA, pd.NA, 23, 24, 25],
            "subset_var_3": [pd.NA, pd.NA, pd.NA, pd.NA, pd.NA],
        }
    )

    assert set(df_verbs.find_ids(df, "id_var", "subset_var_1")) == {1, 2, 3, 5}
    assert set(df_verbs.find_ids(df, "id_var", "subset_var_2")) == {3, 4, 5}
    assert set(df_verbs.find_ids(df, "id_var", "subset_var_3")) == set()


def test_append_max_and_count():
    # Inplace
    df = pd.DataFrame(
        {"group": [1, 1, 1, 2, 2], "value": [1, 2, 2, 3, 4]}, index=[0, 1, 2, 3, 4]
    )

    ret_df = df_verbs.append_max_and_count(
        df, id_col="group", value_col="value", inplace=True
    )
    assert ret_df is df

    df = df.sort_index()
    assert (df["max_value"].values == np.array([2, 2, 2, 4, 4])).all()
    assert (df["count_of_value"].values == np.array([1, 2, 2, 1, 1])).all()

    # Not inplace
    df = pd.DataFrame(
        {"group": [1, 1, 1, 2, 2], "value": [1, 2, 2, 3, 4]}, index=[0, 1, 2, 3, 4]
    )

    ret_df = df_verbs.append_max_and_count(
        df, id_col="group", value_col="value", inplace=False
    )
    assert ret_df is not df
    assert "max_value" not in df.columns

    ret_df = ret_df.sort_index()
    assert (ret_df["max_value"].values == np.array([2, 2, 2, 4, 4])).all()
    assert (ret_df["count_of_value"].values == np.array([1, 2, 2, 1, 1])).all()
