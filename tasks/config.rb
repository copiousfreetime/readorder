require 'configuration'

require 'rake'
require 'tasks/utils'

#-----------------------------------------------------------------------
# General project configuration
#-----------------------------------------------------------------------
Configuration.for('project') {
  name          "readorder"
  version       Readorder::Version.to_s 
  author        "Jeremy Hinegardner"
  email         "jeremy@copiousfreetime.org"
  homepage      "http://copiousfreetime.rubyforge.org/readorder"
  description   Utils.section_of("README", "description")
  summary       description.split(".").first
  history       "HISTORY"
  license       FileList["LICENSE"]
  readme        "README"
}

#-----------------------------------------------------------------------
# Packaging 
#-----------------------------------------------------------------------
Configuration.for('packaging') {
  # files in the project 
  proj_conf = Configuration.for('project')
  files {
    bin       FileList["bin/*"]
    ext       FileList["ext/*.{c,h,rb}"]
    lib       FileList["lib/**/*.rb"]
    test      FileList["spec/**/*.rb", "test/**/*.rb"]
    data      FileList["data/**/*"]
    tasks     FileList["tasks/**/*.r{ake,b}"]
    rdoc      FileList[proj_conf.readme, proj_conf.history,
                       proj_conf.license] + lib
    all       bin + ext + lib + test + data + rdoc + tasks 
  }

  # ways to package the results
  formats {
    tgz true
    zip true
    rubygem Configuration::Table.has_key?('rubygem')
  }
}

#-----------------------------------------------------------------------
# Gem packaging
#-----------------------------------------------------------------------
Configuration.for("rubygem") {
  spec "gemspec.rb"
  Configuration.for('packaging').files.all << spec
}

#-----------------------------------------------------------------------
# Testing
#   - change mode to 'testunit' to use unit testing
#-----------------------------------------------------------------------
Configuration.for('test') {
  mode      "spec"
  files     Configuration.for("packaging").files.test
  options   %w[ --format profile --color ]
  ruby_opts %w[ ]
}

#-----------------------------------------------------------------------
# Rcov 
#-----------------------------------------------------------------------
Configuration.for('rcov') {
  output_dir  "coverage"
  libs        %w[ lib ]
  rcov_opts   %w[ --html ]
  ruby_opts   %w[ ]
  test_files  Configuration.for('packaging').files.test
}

#-----------------------------------------------------------------------
# Rdoc 
#-----------------------------------------------------------------------
Configuration.for('rdoc') {
  files       Configuration.for('packaging').files.rdoc
  main_page   files.first
  title       Configuration.for('project').name
  options     %w[ ]
  output_dir  "doc"
}

#-----------------------------------------------------------------------
# Extensions
#-----------------------------------------------------------------------
Configuration.for('extension') {
  configs   Configuration.for('packaging').files.ext.find_all { |x| 
                %w[ mkrf_conf.rb extconf.rb ].include?( File.basename(x) ) 
            }
}
#-----------------------------------------------------------------------
# Rubyforge 
#-----------------------------------------------------------------------
Configuration.for('rubyforge') {
  project       "copiousfreetime"
  user          "jjh"
  host          "rubyforge.org"
  rdoc_location "#{user}@#{host}:/var/www/gforge-projects/#{project}/readorder"
}


