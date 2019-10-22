#!/usr/bin/env python3
import os
import subprocess
import sys
import argparse
import re
from pathlib import Path
from datetime import datetime, timedelta

def kebab_case(string, separator="-"):
  whitespace_split = re.compile(r"\s+")
  invalid_characters = re.compile(r"[^A-Za-z0-9]")

  words = whitespace_split.split(string)
  filtered_words = []

  for word in words:
    if not word:
      continue
    
    filtered_word = invalid_characters.sub("", word).lower()
    if not filtered_word:
      continue
    
    filtered_words.append(filtered_word)

  return separator.join(filtered_words)


def create_new_note(title, path):

  if path.endswith(".adoc") is False:
    path += ".adoc"

  title_filename = kebab_case(title)
  if path is None:
    path = title_filename + ".adoc"

  path = Path(path)

  if path.is_dir():
    path = path / (title_filename + ".adoc")

  with open(path, mode="w+") as new_note:
    today = datetime.today()
    new_note.write(f"= {title}\nGabriel Arazas <foo.dogsquared@gmail.com>\n{today.strftime('%F')}")


def cli(args):
  argument_parser = argparse.ArgumentParser(description="Recursively converts a directory containing valid Asciidoctor files.")

  # adding all of the flags and options available
  argument_parser.add_argument("title", help="The title of the note.", nargs="?", default=".", type=str)
  argument_parser.add_argument("-p", "--path", help="The path of the note to be created.")

  arguments = argument_parser.parse_args()

  print(arguments)
  create_new_note(arguments.title, path=arguments.path)


if __name__ == "__main__":
  cli(sys.argv)
  