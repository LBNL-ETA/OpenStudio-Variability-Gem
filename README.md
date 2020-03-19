# Openstudio Variability Gem

This gem contains methods to introduce variabilities to extend core OpenStudio SDK. The term "variability" refers to changes in building systems and non-routine events, which are usually ignored in building energy modeling. Those non-routine events include:
- Demand response (DR) events
- Faulty operations
- Building retrofit

This gem is created based on [openstudio-extension-gem](https://github.com/NREL/openstudio-extension-gem). The contents and directory follow the same structure.


## Installation


1. Install Ruby and OpenStudio. If you have already done this, go to step 2.

    Install Ruby using the [RubyInstaller](https://rubyinstaller.org/downloads/archives/) for Ruby 2.2.4 (x64).

    Check the ruby installation returns the correct Ruby version (2.2.4):

    ```ruby
    ruby -v
    ```

    Install Devkit using the [mingw64](https://dl.bintray.com/oneclick/rubyinstaller/DevKit-mingw64-64-4.7.2-20130224-1432-sfx.exe) installer.
    Install Devkit and change directory to its main folder. 
    
    ```ruby
    $ Ruby dk:rb init
    ```

    Make sure the ruby you installed is in config.yml, which will allow Devkit to enhance it.
    ```ruby
    $ Ruby dk:rb install
    ```

    Install OpenStudio v2.9.1.  Create a file ```C:\your-ruby-2.2.4\lib\ruby\site_ruby\openstudio.rb``` and point it to your OpenStudio installation by editing the contents.  E.g.:

    ```ruby
    require 'C:\openstudio-2.9.1\Ruby\openstudio.rb'
    ```

    Verify your OpenStudio and Ruby configuration:
    ```
    ruby -e "require 'openstudio'" -e "puts OpenStudio::Model::Model.new"
    ```

2. Add this line to your application's Gemfile:

    ```ruby
    gem 'openstudio-variability'
    ```

    Run ```ruby$ bundle install``` to install the gem, or install it yourself with:

    ```ruby
    $ gem install 'openstudio-variability'
    ```

## Usage

Usage of this gem can vary based on your purposes. This section introduces the basic rake tasks and rspec tests. 

####    1. Rake Tasks


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

These can all be invoked from the derivative gem by running the following command in a terminal:

``` bundle exec rake <name_of_rake_task>```




####    2. Rspec Tests

A spec test is packaged with this gem to demonstrate the usage. 

## TODO

- [ ] Remove measures from OpenStudio-Measures to standardize on this location
- [ ] Update measures to code standards
- [ ] Review and fill out the gemspec file with author and gem description

# Acknowledgement

This repository is part of the deliverables from the DOE Energy Data Vault project.


# Releasing

* Update change log
* Update version in `/lib/openstudio/openstudio-variability/version.rb`
* Merge down to master
* Release via github
* run `rake release` from master
