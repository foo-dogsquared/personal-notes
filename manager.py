#!/usr/bin/env python3
import os
import subprocess
import sys
import argparse
import re
from datetime import datetime, timedelta
from multiprocessing import cpu_count
from queue import Queue
from threading import Thread
from pathlib import Path

OUTPUT_DIRECTORY = ".output/"


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
  title_filename = kebab_case(title)
  if path is None:
    path = title_filename + ".adoc"

  path = Path(path)

  if path.is_dir():
    title_path = title_filename + ".adoc"
    path = path / title_path

  with open(path, mode="w+") as new_note:
    today = datetime.today()
    new_note.write(f"= {title}\nGabriel Arazas <foo.dogsquared@gmail.com>\n{today.strftime('%F')}\n:toc:\n\n:stem: latexmath\n\n")


# this is the main function to be looking for
def adoc_compile(path, root, available_threads):
  if available_threads is None:
    available_threads = cpu_count()

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
  file_queue = Queue()

  for asciidoctor_file in asciidoctor_files:
    # checking if root folder is included in the process
    if not root:
      # checking if the file is in the root folder
      if not asciidoctor_file.parent.name:
        continue
    
    file_queue.put(asciidoctor_file)

  # compiling the files in parallel
  for core in range(0, available_threads): 
    thread = Thread(target=asciidoctor_process, args=(file_queue,))
    thread.daemon = True
    thread.start()
  
  file_queue.join()

  
def asciidoctor_process(file_queue):
  while True:
    try:
        asciidoctor_file = file_queue.get()
    except queue.Empty:
        break

    file_relative_path = os.path.relpath(asciidoctor_file)
    file_compile_path = OUTPUT_DIRECTORY + file_relative_path[:-(len(asciidoctor_file.suffix))] + ".html"
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
      
      file_queue.task_done()
    except FileNotFoundError:
      print("Seems like Asciidoctor is not yet installed. Please refer to the official website for the installation instructions. (https://asciidoctor.org/)")
      sys.exit(1)

# Shims for passing the namespace arguments into the real functions
def compile_with_args(args):
  adoc_compile(args.dir, args.root, args.threadcount)

def create_with_args(args):
  create_new_note(args.title, args.path)

# The CLI interface
def cli(args):
  argument_parser = argparse.ArgumentParser(description="A simple note manager for my Asciidoctor files setup.")

  # adding all of the flags and options available
  subcommand_parser = argument_parser.add_subparsers(help="Subcommands")

  # creating the parser for the compile subcommand
  compile_parser = subcommand_parser.add_parser("compile", help="Recursively converts a directory containing valid Asciidoctor files.")
  compile_parser.add_argument("dir", help="Specifies the directory to be converted. (default=\".\")", nargs="?", default=".", type=str)
  compile_parser.add_argument("-r", "--root", help="Indicates if the files at the root will also be included in the conversion process.", action="store_true")
  compile_parser.add_argument("--threadcount", help="Indicates the number of simultaneous compilation process to run at a time. Default value is the number of CPU cores on your machine.", type=int)
  compile_parser.set_defaults(func=compile_with_args)

  # creating the parser for the create subcommand
  create_parser = subcommand_parser.add_parser("create", help="Quickly create an Asciidoctor note.")
  create_parser.add_argument("title", help="The title of the new note. Also set as the file name for the new Asciidoctor document.", default="New note", nargs="?", type=str)
  create_parser.add_argument("-p", "--path", help="The path of the note to be created.")
  create_parser.set_defaults(func=create_with_args)

  arguments = argument_parser.parse_args()

  arguments.func(arguments)

# if the program is executed directly
if __name__ == "__main__":
  cli(sys.argv)
