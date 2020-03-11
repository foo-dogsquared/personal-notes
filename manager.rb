#!/usr/bin/env ruby

# A simple notes manager specifically for this setup.

require 'fileutils'
require 'optparse'
require 'pathname'

require 'asciidoctor'

OUTPUT_DIRECTORY = ".output"
TEMPLATES_DIRECTORY = "templates/output"


def kebab_case string, separator = "-"
  whitespace_split = /\s+/
  invalid_characters = /[^A-Za-z0-9]/

  words = string.split(whitespace_split)
  filtered_words = []

  for word in words
    if !word
      next
    end

    filtered_word = word.sub(invalid_characters, "").downcase
    if !filtered_word
      next
    end

    filtered_words.append(filtered_word)
  end

  return filtered_words.join(separator)
end


private def check_path_is_directory path = nil
  if path == nil
    path = Pathname.getwd
  end

  path = Pathname.new(path)

  if !path.exist?
    raise ArgumentError, 'Given path does not exist.'
  end

  if path.file?
    raise ArgumentError, 'Given path is a file.'
  end

  return path
end


private def check_path_is_file path = nil
  path = Pathname.new(path)

  if !path.exist?
    raise ArgumentError, 'Given path does not exist.'
  end

  if path.directory?
    raise ArgumentError, 'Given path is a directory.'
  end

  return path
end


def create_asciidoctor_string path = nil
  path = check_path_is_directory path
  resulting_string = "= #{path.basename.to_path.capitalize}\n\n"

  for node in path.children
    if node.file? and node.extname == ".adoc"
      node_as_asciidoctor_obj = Asciidoctor.load_file node
      resulting_string += "* link:#{node.basename(".*").sub_ext(".html")}[#{node_as_asciidoctor_obj.doctitle}]\n"
    elsif node.directory?
      resulting_string += "* link:#{node.basename(".*") + "index.html"}[#{node.basename.to_path.capitalize}]\n"
    end
  end

  return resulting_string
end


def compile_asciidoctor_doc path = nil, offline = false
  asciidoctor_doc = Asciidoctor.load_file path, safe: :safe, template_dir: TEMPLATES_DIRECTORY, header_footer: true
  asciidoctor_doc.set_attribute('toc', '')

  output_file_dir = Pathname.new(OUTPUT_DIRECTORY) + path.dirname
  FileUtils.mkpath(output_file_dir)
  output_file = output_file_dir + path.basename(".*").sub_ext(".html")
  file = File.new output_file, mode = "w+"

  file.write(asciidoctor_doc.convert)
  return true
end


def compile_all_asciidoctor_docs path = nil, thread_count = 1, offline = false
  path = check_path_is_directory path

  asciidoctor_files = path.glob("**/*.adoc")
  files_queue = Queue.new
  asciidoctor_files.each { |path| files_queue << path }

  mutex_lock = Mutex.new
  total_files_count = files_queue.length
  compiled_files_count = 0
  progress_bar_spacing = 15

  puts "Found #{files_queue.length} files to compile."

  threads = []
  thread_count.times do 
    threads << Thread.new {
      while files_queue.size > 0
        file = files_queue.pop

        begin
          compile_asciidoctor_doc file

          # updating the progress bar
          # we have to update them through a mutex since we are in a separate thread 
          # and the variables we're updating are local variables
          mutex_lock.synchronize do
            compiled_files_count += 1
            ratio = (compiled_files_count.to_f / total_files_count) * 100
            tasks_per_block = total_files_count.to_f / progress_bar_spacing
            progress = "=" * (compiled_files_count.to_f / tasks_per_block).round unless compiled_files_count < tasks_per_block
            printf("\r[%-#{progress_bar_spacing}s] %d/%d %d%%", progress, compiled_files_count, total_files_count, ratio)
         end

        rescue
          next
        end
      end
    }
  end

  threads.each { |thread| thread.join }
end

def recursively_create_index path = nil
  path = check_path_is_directory path

  for node in path.children
    if node.file?
      next
    end

    resulting_string = create_asciidoctor_string node
    asciidoctor_doc = Asciidoctor.load resulting_string, safe: :safe, template_dir: TEMPLATES_DIRECTORY, header_footer: true
    output_file = Pathname.new(".output") + node + "index.html"
    file = File.new output_file, mode = "w+"
    file.write(asciidoctor_doc.convert)

    # Create an index file to its subdirectory
    recursively_create_index(node)
  end
end


subtext = <<HELP
Commonly used command are:
   create  :     create a document from an ERB template
   compile :     compile a set of Asciidoctor notes
See 'opt.rb COMMAND --help' for more information on a specific command.
HELP


# Parsing the command line

# The options object where the settings will be stored
options = {}

global_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options]"

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end

  opts.on("-v", "--[no-]verbose", "Print extra info") do |v|
    options[:verbose] = v
  end

  opts.separator ""
  opts.separator subtext
end

subcommands = {
  "create" => OptionParser.new do |opts|
    options[:create] = {}
    opts.banner = "Usage: #{__FILE__} create [options]"

    opts.on("-pPATH", "--path=PATH", "set the path of the newly created document") do |path|
      options[:create][:path] = path
    end

    opts.on("-tTITLE", "--title=TITLE", "set the title of the document") do |title|
      options[:create][:title] = title
    end
  end,
  "compile" => OptionParser.new do |opts|
    options[:compile] = {}
    options[:compile][:dir] = "."
    options[:compile][:output_dir] = options[:compile][:dir]

    opts.on("--thread-count=NUMBER", Integer, "set the number of threads for simultaneous compilation") do |num|
      options[:compile][:threadcount] = num
    end

    opts.on("--offline", "set if the documents are set to be read in an offline environment") do |v|
      options[:compile][:offline] = v 
    end

    opts.on("-dPATH", "--directory=PATH", "set the directory of the starting path; default is the current directory") do |dir|
      options[:compile][:dir] = dir
    end

    opts.on("-oPATH", "--output-dir=PATH", "set where the output will be written") do |dir|
      options[:compile][:output] = dir
    end

    opts.on("-TPATH", "--templates=PATH", "set the template directory of the documents") do |template_path|
      options[:compile][:templates] = template_path
    end
  end
}

global_parser.order!
command = ARGV.shift
subcommands[command].order!

case command
when "compile"
  compile_all_asciidoctor_docs options[:compile][:dir], options[:compile][:threadcount]
when "create"
  puts "WORLD"
end

