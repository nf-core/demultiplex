#!/usr/bin/env python

"""Provide a command line tool to validate and transform tabular samplesheets."""


import argparse
import csv
import logging
import sys
from pathlib import Path

from urllib import request

logger = logging.getLogger()


class RowChecker:
    """
    Define a service that can validate and transform each given row.

    Attributes:
        modified (list): A list of dicts, where each dict corresponds to a previously
            validated and transformed row. The order of rows is maintained.

    """

    def __init__(
        self,
        fc_col="flowcell",
        samplesheet_col="samplesheet",
        lane_col="lane",
        run_dir_col="run_dir",
        **kwargs,
    ):
        """
        Initialize the row checker with the expected column names.

        Args:
            sample_col (str): The name of the column that contains the sample name
                (default "sample").
            first_col (str): The name of the column that contains the first (or only)
                FASTQ file path (default "fastq_1").
            second_col (str): The name of the column that contains the second (if any)
                FASTQ file path (default "fastq_2").
            single_col (str): The name of the new column that will be inserted and
                records whether the sample contains single- or paired-end sequencing
                reads (default "single_end").

        """
        super().__init__(**kwargs)
        self._fc_col = fc_col
        self._samplesheet_col = samplesheet_col
        self._lane_col = lane_col
        self._run_dir_col = run_dir_col
        self._seen = set()
        self.modified = []

    def validate_and_transform(self, row):
        """
        Perform all validations on the given row.
        Args:
            row (dict): A mapping from column headers (keys) to elements of that row
                (values).

        """
        self._validate_fc(row)
        self._validate_samplesheet(row)
        self._validate_lane(row)
        self._validate_run_dir(row)
        self._seen.add((row[self._fc_col], row[self._samplesheet_col]))
        self.modified.append(row)

    def _validate_fc(self, row):
        """Assert that the flowcell name exists and check format."""
        assert len(row[self._fc_col]) > 0, "Flowcell name is required."
        assert (
            len(row[self._fc_col].split("_")) == 4
        ), "Flowcell name must have the following format: 'DDMMYY_SERIAL_RUN_FC'."

    def _validate_samplesheet(self, row):
        """Assert that the samplesheet exists and has the right format."""
        assert len(row[self._samplesheet_col]) > 0, "SampleSheet file is required."
        assert (
            Path(row[self._samplesheet_col]).suffix == ".csv"
        ), "SampleSheet file must have the .csv extension."
        assert (
            Path(row[self._samplesheet_col]).exists()
            or request.urlopen(row[self._samplesheet_col]).getcode() == 200
        ), "SampleSheet file must exist."

    def _validate_lane(self, row):
        """Assert that the second FASTQ entry has the right format if it exists."""
        if row[self._lane_col]:
            assert row[
                self._lane_col
            ].isdigit(), "Lane number must be a positive integer."

    def _validate_run_dir(self, row):
        """Assert that the run directory exists and is a directory or tar.gz file"""
        run_dir_path = Path(row[self._run_dir_col])
        assert len(row[self._run_dir_col]) > 0, "Run directory is required."
        assert (
            Path(row[self._run_dir_col]).exists()
            or request.urlopen(row[self._run_dir_col]).getcode() == 200
        ), "Run directory must exist."


def sniff_format(handle):
    """
    Detect the tabular format.

    Args:
        handle (text file): A handle to a `text file`_ object. The read position is
        expected to be at the beginning (index 0).

    Returns:
        csv.Dialect: The detected tabular format.

    .. _text file:
        https://docs.python.org/3/glossary.html#term-text-file

    """
    peek = handle.read(2048)
    sniffer = csv.Sniffer()
    if not sniffer.has_header(peek):
        logger.critical(f"The given sample sheet does not appear to contain a header.")
        sys.exit(1)
    dialect = sniffer.sniff(peek)
    handle.seek(0)
    return dialect


def check_samplesheet(file_in, file_out):
    """
    Check that the tabular samplesheet has the structure expected by nf-core pipelines.

    Validate the general shape of the table, expected columns, and each row. Also add
    an additional column which records whether one or two FASTQ reads were found.

    Args:
        file_in (pathlib.Path): The given tabular samplesheet. The format can be either
            CSV, TSV, or any other format automatically recognized by ``csv.Sniffer``.
        file_out (pathlib.Path): Where the validated and transformed samplesheet should
            be created; always in CSV format.

    Example:
        This function checks that the samplesheet follows the following structure:
            flowcell,samplesheet,lane,run_dir
            DDMMYY_SERIAL_NUMBER_FC,/path/to/SampleSheet.csv,1,/path/to/sequencer/output
            DDMMYY_SERIAL_NUMBER_FC,/path/to/SampleSheet.csv,2,/path/to/sequencer/output
            DDMMYY_SERIAL_NUMBER_FC2,/path/to/SampleSheet2.csv,1,/path/to/sequencer/output2

    """
    required_columns = {"flowcell", "samplesheet", "run_dir"}
    # See https://docs.python.org/3.9/library/csv.html#id3 to read up on `newline=""`.
    with file_in.open(newline="") as in_handle:
        reader = csv.DictReader(in_handle, dialect=sniff_format(in_handle))
        # Validate the existence of the expected header columns.
        if not required_columns.issubset(reader.fieldnames):
            logger.critical(
                f"The sample sheet **must** contain the column headers: {', '.join(required_columns)}."
            )
            sys.exit(1)
        # Validate each row.
        checker = RowChecker()
        for i, row in enumerate(reader):
            try:
                checker.validate_and_transform(row)
            except AssertionError as error:
                logger.critical(f"{str(error)} On line {i + 2}.")
                sys.exit(1)

        header = list(reader.fieldnames)
        # See https://docs.python.org/3.9/library/csv.html#id3 to read up on `newline=""`.
        with file_out.open(mode="w", newline="") as out_handle:
            writer = csv.DictWriter(out_handle, header, delimiter=",")
            writer.writeheader()
            for row in checker.modified:
                writer.writerow(row)


def parse_args(argv=None):
    """Define and immediately parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Validate and transform a tabular samplesheet.",
        epilog="Example: python check_samplesheet.py samplesheet.csv samplesheet.valid.csv",
    )
    parser.add_argument(
        "file_in",
        metavar="FILE_IN",
        type=Path,
        help="Tabular input samplesheet in CSV or TSV format.",
    )
    parser.add_argument(
        "file_out",
        metavar="FILE_OUT",
        type=Path,
        help="Transformed output samplesheet in CSV format.",
    )
    parser.add_argument(
        "-l",
        "--log-level",
        help="The desired log level (default WARNING).",
        choices=("CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"),
        default="WARNING",
    )
    return parser.parse_args(argv)


def main(argv=None):
    """Coordinate argument parsing and program execution."""
    args = parse_args(argv)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")
    if not args.file_in.is_file():
        logger.error(f"The given input file {args.file_in} was not found!")
        sys.exit(2)
    args.file_out.parent.mkdir(parents=True, exist_ok=True)
    check_samplesheet(args.file_in, args.file_out)


if __name__ == "__main__":
    sys.exit(main())
