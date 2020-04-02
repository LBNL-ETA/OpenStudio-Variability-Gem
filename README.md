# Openstudio Variability Gem

This gem contains methods to introduce variabilities to extend core OpenStudio SDK. The term "variability" refers to changes in building systems efficiency, operation, or controls, which are non-routine events. Those non-routine events include:
- Demand response events
- Faulty operations of HVAC systems
- Building retrofit at any specific time of the year

This gem is created based on [openstudio-extension-gem](https://github.com/NREL/openstudio-extension-gem). The contents and directory follow the same structure.

## License

See [license.txt](License.txt) for details.

See [this disclaimer page](https://www.lbl.gov/disclaimers/) for more Privacy, Security, Copyright, Disclaimers, and Accessibility Information

## Installation

#### 1. Install Ruby and OpenStudio.
If you have already done this, go to step 2.

Install Ruby using the [RubyInstaller](https://rubyinstaller.org/downloads/archives/) for Ruby 2.2.4 (x64).

Check the ruby installation returns the correct Ruby version (2.2.4):

```ruby
ruby -v
```

Install Devkit using the [mingw64](https://dl.bintray.com/oneclick/rubyinstaller/DevKit-mingw64-64-4.7.2-20130224-1432-sfx.exe) installer.
Install Devkit and change directory to its main folder. 

```ruby
$ Ruby dk.rb init
```

Make sure the ruby you installed is in config.yml, which will allow Devkit to enhance it.
```ruby
$ Ruby dk.rb install
```

Install OpenStudio v2.9.1.  Create a file ```C:\your-ruby-2.2.4\lib\ruby\site_ruby\openstudio.rb``` and point it to your OpenStudio installation by editing the contents.  E.g.:

```ruby
require 'C:\openstudio-2.9.1\Ruby\openstudio.rb'
```

Verify your OpenStudio and Ruby configuration:
```
ruby -e "require 'openstudio'" -e "puts OpenStudio::Model::Model.new"
```

#### 2. Use the variability gem in your project 

Add this line to your application's Gemfile:

```ruby
gem 'openstudio-variability'
```

Run ```ruby$ bundle install``` to install the gem, or install it yourself with:

```ruby
$ gem install 'openstudio-variability'
```

## Usage

Usage of this gem can vary based on your purposes. This section introduces the basic rake tasks and rspec tests. 

#### 1. Rake Tasks


To list all available rake tasks: ``` bundle exec rake -T ```

Common rake tasks are inherited from the [openstudio-extension-gem](https://github.com/NREL/openstudio-extension-gem#rake-tasks).

| Rake Task | Description |
| --------- | ----------- |
| openstudio:list_measures             | List all measures in the calling gem |
| openstudio:measures:add_license      | Add License File to measures in the calling gem |
| openstudio:measures:add_readme       | Add README.md.erb file if it and the README markdown file do not already exist for a measure |
| openstudio:measures:copy_resources   | Copy the resources files to individual measures in the calling gem |
| openstudio:measures:update_copyright | Update copyright on measure files in the calling gem |
| openstudio`:runner:`init             | Create a runner.conf file running simulations |
| openstudio:stage_bcl                 | Copy the measures to a location that can be uploaded to BCL |
| openstudio:push_bcl                  | Upload measures from the specified location to the BCL |
| openstudio:test_with_docker          | Use openstudio docker image to run tests |
| openstudio:test_with_openstudio      | Use openstudio system ruby to run tests |
| openstudio:update_measures           | Run the CLI task to check for measure updates and update the measure xml files |

Rake tasks can be invoked by running: ``` bundle exec rake <name_of_rake_task>```


#### 2. Rspec Tests

A spec test is packaged with this gem to demonstrate the usage of the variability gem.

Several demonstration test cases are included in the ```...spec/tests``` folder.

* ```test_single_seed_variability_spec.rb``` contains the script to create a single OpenStudio workflow with a seed OpenStudio model and add variability measures to it.
* ```test_multiple_seed_variability_spec.rb``` contains the script to create multiple OpenStudio workflows with a seed OpenStudio model and add variability measures to them.
* ```test_demand_response_variability_spec.rb``` contains the script to a single OpenStudio workflows with a seed OpenStudio model and add demand response variability measures to them.
* ```test_faulty_operation_variability_spec.rb``` contains the script to a single OpenStudio workflows with a seed OpenStudio model and add faulty operation variability measures to them.
* ```test_retrofit_variability_spec.rb``` contains the script to a single OpenStudio workflows with a seed OpenStudio model and add retrofit variability measures to them.

To run the tests, change directory to the folder and ```bundle exec rspec <name_of_test_variability_spec.rb>```.
Simulation(s) will run in the ```...spec/test_runs``` folder.


# Acknowledgement

This repository is part of the deliverables from the DOE Energy Data Vault project. This research was supported by the Assistant Secretary for Energy Efficiency and Renewable Energy, Office of Building Technologies of the United States Department of Energy, under Contract No. DE-AC02-05CH11231.