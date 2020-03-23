#!/usr/bin/env ruby

# A simple notes manager specifically for this setup.

require 'erb'
require 'fileutils'
require 'optparse'
require 'pathname'

require 'asciidoctor'


$OUTPUT_DIRECTORY = ".output"
$TEMPLATES_DIRECTORY = "templates"

$DEFAULT_TEMPLATE = "= <%= title %>
:toc:

:stem: latexmath
"


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


def create_document kwargs
  title = kwargs.fetch(:title, "Untitled")
  template_file = kwargs.fetch(:template_file, "#{$TEMPLATES_DIRECTORY}/input/document.adoc.erb")
  path = kwargs.fetch(:path, "./")
  template_file = Pathname.new template_file

  # Creating the directories of the path
  path = Pathname.new path
  FileUtils.mkpath(path)

  file_name = kebab_case title
  path += file_name + ".adoc"

  begin
    template = File.read template_file
  rescue
    template = $DEFAULT_TEMPLATE
  end

  b = binding
  erb = ERB.new template, :trim_mode => "-"
  output_file = File.new path.to_s, mode = "w+"
  output_file.write erb.result b
end


def compile_asciidoctor_doc path = nil, offline = false, template_dir = "#{$TEMPLATES_DIRECTORY}/output"
  asciidoctor_doc = Asciidoctor.load_file path, :safe => :safe, :header_footer => true, :template_dir => "./templates/output"
  asciidoctor_doc.set_attribute('toc', 'left')

  output_file_dir = Pathname.new($OUTPUT_DIRECTORY) + path.dirname
  FileUtils.mkpath(output_file_dir)
  output_file = output_file_dir + path.basename(".*").sub_ext(".html")
  file = File.new output_file, mode = "w+"

  file.write(asciidoctor_doc.convert)
  return true
end


def compile_all_asciidoctor_docs kwargs = {}
  path = kwargs.fetch(:dir, nil)
  thread_count = kwargs.fetch(:thread_count, 1)
  offline = kwargs.fetch(:offline, false)
  templates_dir = kwargs.fetch(:templates, "#{$TEMPLATES_DIRECTORY}/output")
  path = check_path_is_directory path

  # Setting up the task list
  asciidoctor_files = path.glob("**/*.adoc")
  files_queue = Queue.new
  asciidoctor_files.each { |path| files_queue << path }
  total_files_count = files_queue.length
  compiled_files_count = 0

  # Setting up the progress bar variables
  mutex_lock = Mutex.new
  progress_bar_spacing = 20
  tasks_per_block = total_files_count.to_f / progress_bar_spacing

  puts "Found #{files_queue.length} files to compile."

  threads = []
  thread_count.times do 
    threads << Thread.new {
      while files_queue.size > 0
        file = files_queue.pop

        begin
          # updating the progress bar
          # we have to update them through a mutex since we are in a separate thread 
          # and the variables we're updating are local variables
          mutex_lock.synchronize do
            compile_asciidoctor_doc file, offline: offline, template_dir: templates_dir
            compiled_files_count += 1
            ratio = (compiled_files_count.to_f / total_files_count) * 100
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

See '#{__FILE__} COMMAND --help' for more information on a specific command.
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

    opts.on("-TTITLE", "--template=TITLE", "set the title of the document") do |file|
      options[:create][:template_file] = file
    end
  end,
  "compile" => OptionParser.new do |opts|
    options[:compile] = {}

    opts.on("--thread-count=NUMBER", Integer, "set the number of threads for simultaneous compilation") do |num|
      options[:compile][:thread_count] = num
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
  compile_all_asciidoctor_docs({ **options[:compile] })
when "create"
  create_document({ **options[:create] })
end

