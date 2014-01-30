#! /usr/bin/env ruby

require 'pp'
require_relative 'compile'


# Default

@packages = ['core','common','es5','array','date','range','function','number','object','regexp','string','inflections','language','date_locales']
@default_packages = @packages.values_at(0,1,2,3,4,5,6,7,8,9,10)
@delimiter = 'console.info("-----BREAK-----");'

if @packages.include?(ARGV[0])
  @version = 'custom'
  @custom_packages = ARGV[0..-1]
else
  @version  = ARGV[0]
  @custom_packages = ARGV[1..-1]

end

if @custom_packages.length > 0
  @custom_packages.unshift('common')
  @custom_packages.unshift('core')
  @custom_packages.uniq!
end

if !@version
  $stderr.puts "No version specified!"
  exit false
end

@copyright = File.open('release/copyright.txt').read.gsub(/VERSION/, @version)

@precompiled_notice = <<NOTICE
Note that the files in this directory are not prodution ready. They are
intended to be concatenated together and wrapped with a closure.
NOTICE


PARENT_DIR = "release"
PRECOMPILED_DIR = PARENT_DIR     + "/precompiled"
PRECOMPILED_MIN_DIR = PARENT_DIR + "/precompiled/minified"
PRECOMPILED_DEV_DIR = PARENT_DIR + "/precompiled/development"

TMP_COMPILED_FILE = 'tmp/compiled.js'
TMP_UNCOMPILED_FILE = 'tmp/uncompiled.js'

`mkdir #{PRECOMPILED_DIR}`
`mkdir #{PRECOMPILED_MIN_DIR}`
`mkdir #{PRECOMPILED_DEV_DIR}`

def concat
  File.open(TMP_UNCOMPILED_FILE, 'w') do |file|
    @packages.each do |p|
      content = get_content(p)
      file.puts content = content + @delimiter
    end
  end
end

def get_content(package)
  if package == 'date_locales'
    `cat lib/locales/*`
  else
    content = File.open(get_file_path(package)).read
    content.gsub(/^\s*\/\*\*\*COMPILER REMOVE\*\*\*.*\*\*\*END\*\*\*\/\n/m, '')
  end
end

def get_file_path(package)
  if (package == 'core')
    path = 'core/' + package
  else
    path = package
  end
  "lib/#{path}.js"
end

def create_all_development
  if @custom_packages.length > 0
    create_development(@custom_packages, 'custom')
  else
    create_development(@packages, 'full')
    create_development(@default_packages, 'default')
  end
end

def create_development(packages, type)
  filename = if type == 'default'
    "/sugar.development.js"
  else
    "/sugar-#{type}.development.js"
  end
  full_content = ''
  packages.each do |p|
    content = get_content(p)
    content.gsub!(/^\s*'use strict';\n/, '')
    # don't think I need to store this
    File.open(PRECOMPILED_DEV_DIR + "/#{p}.js", 'w').write(content)
    full_content << content
  end
  File.open(PARENT_DIR + filename, 'w').write(@copyright + wrap(full_content))
end

def split_compiled
  contents = File.open(TMP_COMPILED_FILE, 'r').read.split(@delimiter)
  @packages.each_with_index do |name, index|
    File.open(PRECOMPILED_MIN_DIR + "/#{name}.js", 'w') do |f|
      f.puts contents[index].gsub(/\A\n+/, '')
    end
  end
  `echo "#{@precompiled_notice}" > #{PRECOMPILED_MIN_DIR}/readme.txt`
end

def create_all_packages
  if @custom_packages.length > 0
    create_package('custom', @custom_packages)
  else
    create_package('full', @packages)
    create_package('default', @default_packages)
  end
end

def create_package(name, arr)
  contents = ''
  arr.each do |s|
    contents << File.open(PRECOMPILED_MIN_DIR + "/#{s}.js").read
  end
  contents = @copyright + wrap_minified(contents.sub(/\n+\Z/m, ''))
  ext = name == 'default' ? '' : '-' + name
  File.open(PARENT_DIR + "/sugar#{ext}.min.js", 'w').write(contents)
end

def wrap_minified(js)
  "(function(){#{js}})();"
end

def wrap(js)
  <<-EOT
(function(){
  'use strict';
#{js}
})();
  EOT
end

def cleanup
  `rm #{TMP_COMPILED_FILE}`
  `rm #{TMP_UNCOMPILED_FILE}`
end

concat
compile(TMP_UNCOMPILED_FILE, TMP_COMPILED_FILE)
split_compiled
create_all_packages
create_all_development
#cleanup

