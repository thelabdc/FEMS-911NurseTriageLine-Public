import json
import shutil
import subprocess
import textwrap
from pathlib import Path
from typing import List, Optional, Tuple, Union

import click
import papermill as pm
import yaml

from .datafiles import NOTEBOOK_DIR, OUTPUT_DIR, SRC_DIR, TEST_DIR
from .utils import _open_or_yield, compute_sha


@click.group()
def cli():
    """ Commands for executing the NTL analysis """
    pass


@cli.command("style")
@click.option(
    "--source-dir",
    "-s",
    default=None,
    multiple=True,
    help="The directory to style. Default is both `src` and `tests`",
)
def style_command(source_dir: Optional[Tuple[str]]):
    """ Style all code files """
    all_source_dirs: List[Union[str, Path]] = (
        list(source_dir) if source_dir else [SRC_DIR, TEST_DIR]
    )

    for this_source_dir in all_source_dirs:
        # Style python files
        subprocess.call(["poetry", "run", "black", str(this_source_dir)])
        subprocess.call(["poetry", "run", "isort", str(this_source_dir)])

        # Style python notebooks
        subprocess.call(["poetry", "run", "nbqa", "black", str(this_source_dir)])
        subprocess.call(["poetry", "run", "nbqa", "isort", str(this_source_dir)])

        # Style R files
        subprocess.call(
            [
                "Rscript",
                "-e",
                f'styler::style_dir("{this_source_dir}", filetype=c("R", "Rmd"))',
            ]
        )


@cli.command("run-all")
@click.option("--step", "-s", default=None)
def run_all_command(step: Optional[str]):
    base_output_dir = OUTPUT_DIR / "notebooks"

    if not step or step == "1":
        # Run the pre-analysis
        preanalysis_dir = NOTEBOOK_DIR / "100_preanalysis"
        output_dir = base_output_dir / "100_preanalysis"
        output_dir.mkdir(exist_ok=True, parents=True)

        for filename in sorted(preanalysis_dir.glob("*.ipynb")):
            click.echo(f"Running {filename}...")
            pm.execute_notebook(filename, output_dir / filename.name)

    if not step or step == "3":
        # Execute merging scripts
        merging_dir = NOTEBOOK_DIR / "300_merge_and_clean"
        output_dir = base_output_dir / "300_merge_and_clean"
        output_dir.mkdir(exist_ok=True, parents=True)

        for filename in sorted(merging_dir.glob("*.ipynb")):
            click.echo(f"Running {filename}...")
            pm.execute_notebook(filename, output_dir / filename.name)

    if not step or step == "4":

        output_dir = base_output_dir / "400_analysis"
        output_dir.mkdir(exist_ok=True, parents=True)
        filenames = sorted(Path("src").rglob("400_analysis/*"), key=lambda x: x.name)
        for filename in filenames:
            click.echo(f"Running {filename}...")
            if filename.name.endswith("ipynb"):
                pm.execute_notebook(filename, output_dir / filename.name)
            elif filename.name.endswith("R"):
                subprocess.run(["Rscript", filename], check=True)
            elif filename.name.endswith("Rmd"):
                subprocess.run(
                    ["Rscript", "-e", f'rmarkdown::render("{filename}")'], check=True
                )
                shutil.move(
                    str(filename.with_suffix(".html")),
                    output_dir / filename.with_suffix(".html").name,
                )
            else:
                raise ValueError(f"Unsupported filetype extesion for {filename}")


@cli.group("inventory")
def inventory_group():
    """
    Commands related to the data inventory
    """


@inventory_group.command("create")
@click.option(
    "--data-dir",
    "-d",
    "data",
    type=click.Path(exists=True, dir_okay=True, file_okay=False, readable=True),
    default="data",
    help="The directory containing the data to inventory",
)
def create_inventory_command(data: str):
    """ Create an inventory from a directory """
    data_dir = Path(data)
    objs = []
    for path in data_dir.rglob("*"):
        if path.name == "inventory.yml" or not path.is_file():
            continue
        objs.append(
            {
                "path": str(path.relative_to(data_dir)),
                "sha256": compute_sha(path),
            }
        )
    with open(data_dir / "inventory.yml", "wt") as outfile:
        yaml.dump({"files": objs}, outfile)


@inventory_group.command("compute-sha")
@click.option(
    "--data-dir",
    "-d",
    "data",
    type=click.Path(exists=True, dir_okay=True, file_okay=False, readable=True),
    default="data",
)
def compute_sha_command(data: str):
    """ Append the shas to every entry in an inventory file """
    data_dir = Path(data)
    with open(data_dir / "inventory.yml", "rt") as infile:
        inventory = yaml.safe_load(infile)

    for file_obj in inventory["files"]:
        file_path = Path(file_obj["path"])
        sha = compute_sha(data_dir / file_path)
        file_obj["sha256"] = sha

    with open(data_dir / "inventory.yml", "wt") as outfile:
        yaml.safe_dump(inventory, outfile)


@inventory_group.command("verify")
@click.option(
    "--data-dir",
    "-d",
    "data",
    type=click.Path(exists=True, dir_okay=True, file_okay=False, readable=True),
    default="data",
)
def verify_inventory_command(data: str):
    """ Verify that all data files match the shas in inventory """
    data_dir = Path(data)
    with open(data_dir / "inventory.yml", "rt") as infile:
        inventory = yaml.safe_load(infile)

    for file_obj in inventory["files"]:
        expected_sha = file_obj.get("sha256")
        if not expected_sha:
            continue

        file_path = Path(file_obj["path"])
        sha = compute_sha(data_dir / file_path)
        if not sha == expected_sha:
            click.echo(f"file {file_obj['path']} does not match sha")


@inventory_group.command("recreate-data-dir")
@click.option(
    "--data-dir",
    "-d",
    "old_data",
    type=click.Path(exists=True, dir_okay=True, file_okay=False, readable=True),
    default="data",
)
@click.option(
    "--new-data-dir",
    "-n",
    "new_data",
    type=click.Path(exists=False),
    default="new_data",
)
def recreate_data_dir_command(old_data: str, new_data: str):
    new_data_dir = Path(new_data)
    old_data_dir = Path(old_data)
    with open(old_data_dir / "inventory.yml", "rt") as infile:
        data = yaml.safe_load(infile)

    new_data_dir.mkdir(parents=True)
    for file_obj in data["files"]:
        file_path = Path(file_obj["path"])
        (new_data_dir / file_path).parent.mkdir(exist_ok=True, parents=True)
        shutil.copy(old_data_dir / file_path, new_data_dir / file_path)
    shutil.copy(old_data_dir / "inventory.yml", new_data_dir / "inventory.yml")

    (new_data_dir / "data_shared_externally").mkdir(exist_ok=True, parents=True)


@cli.command("convert-nb-to-rmd")
@click.argument("filename")
@click.option(
    "--output",
    "-o",
    default="-",
    help="The location to write the converted notebook to",
)
def convert_nb_to_rmd_command(filename: str, output: str):
    with open(filename, "rt") as infile:
        data = json.load(infile)

    out = [
        textwrap.dedent(
            r"""
        ---
        title: AB Tests additional plots
        author: Rebecca Johnson
        date: '`r format(Sys.Date(), "%B %d, %Y")`'
        header-includes:
        - \usepackage{float,booktabs,longtable,tabu,array}
        - \usepackage[small]{caption}
        - \captionsetup[table]{position=bottom}
        - \floatplacement{figure}{H}  #make every figure with caption = h, this was the fix
        - \floatplacement{table}{H}  #make every figure with caption = h, this was the fix
        output:
        pdf_document:
            fig_caption: yes
            fig_height: 9
            fig_width: 9
            latex_engine: xelatex
            keep_tex: true
            keep_md: true
            toc: true
        geometry: "left=1in,right=1in,top=1in,bottom=1in"
        graphics: yes
        fontsize: 11pt
        ---"""
        ),
        "\n\n",
    ]

    out.append(
        textwrap.dedent(
            r"""
        ```{r, include=FALSE, echo=FALSE}
        library(ggplot2)
        library(dplyr)
        library(here)

        source(here("src", "R", "000_rmd_setup.R"))
        source(here("src", "R", "000_constants.R"))
        source(here("src", "R", "001_viz_utils.R"))
        ```"""
        )
    )
    out.append("\n\n")

    for cell in data["cells"]:
        if cell["cell_type"] == "code":
            out.append("```{r}\n")
            out.append("".join(cell["source"]))
            out.append("\n```\n\n")
        else:
            out.append("".join(cell["source"]))
            out.append("\n\n")

    total_out = "".join(out)
    with _open_or_yield(output, mode="wt") as outfile:
        outfile.write(total_out)


if __name__ == "__main__":
    cli()
