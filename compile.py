#!/usr/bin/env python3
import os
import subprocess
import sys
import argparse
import re
from pathlib import Path

# this is the main function to be looking for
def adoc_compile(path, root):
  # creating a path instance for containing all of the files
  directory_path = Path(path)

  asciidoctor_extensions = ["adoc"]
  asciidoctor_files = []
  for file_extension in asciidoctor_extensions:
    # converting the generator into a list of files
    valid_files = list(directory_path.glob("**/*." + file_extension))
    for note in valid_files:
      asciidoctor_files.append(note)

  if len(asciidoctor_files) == 0:
    print("No detected Asciidoctor files")
    exit
  
  # tracking how many files have been successfully converted
  asciidoctor_file_success_counter = 0

  for asciidoctor_file in asciidoctor_files:
    file_relative_path = os.path.relpath(asciidoctor_file)

    # checking if root folder is included in the process
    if not root:
      # checking if the file is in the root folder
      if not asciidoctor_file.parent.name:
        continue

    # running the Asciidoctor program
    file_compile_path = ".output/" + file_relative_path[:-(len(asciidoctor_file.suffix))] + ".html"
    try:
      compilation_result = subprocess.run([
        "asciidoctor",
        "--attribute", "toc",
        file_relative_path,
        "--out-file", file_compile_path
      ])

      # checking if the file conversion is successful for the reliable end message
      if compilation_result.returncode == 1:
        print(file_relative_path + " has failed to be converted.")
      elif compilation_result.returncode == 0:
        print("Converting " + file_relative_path)
        asciidoctor_file_success_counter += 1
    except FileNotFoundError:
      print("Seems like Asciidoctor is not yet installed. Please refer to the official website for the installation instructions. (https://asciidoctor.org/)")
      sys.exit(1)

  if asciidoctor_file_success_counter:
    print("Converted " + str(asciidoctor_file_success_counter) + " Asciidoctor files.")

def cli(args):
  argument_parser = argparse.ArgumentParser(description="Recursively converts a directory containing valid Asciidoctor files.")

  # adding all of the flags and options available
  argument_parser.add_argument("dir", help="Specifies the directory to be converted. (default=\".\")", nargs="?", default=".", type=str)
  argument_parser.add_argument("-r", "--root", help="Indicates if the files at the root will also be included in the conversion process.", action="store_true")

  arguments = argument_parser.parse_args()

  adoc_compile(arguments.dir, arguments.root)

# if the program is executed directly
if __name__ == "__main__":
  cli(sys.argv)
