# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

require_relative '../spec_helper'
require 'JSON'
require 'fileutils'

RSpec.describe OpenStudio::Variability do
  it 'has a version number' do
    expect(OpenStudio::Variability::VERSION).not_to be nil
  end

  it 'has a measures directory' do
    instance = OpenStudio::Variability::Variability.new
    expect(File.exist?(instance.measures_dir)).to be true
  end

  # Spec examples for variability
  puts 'Testing specs beginning here...'

  it 'should run single simulation test with variability measures' do
    OpenStudio::Extension::Extension::DO_SIMULATIONS = true

    gem_root_path = File.expand_path("../..", Dir.pwd)

    spec_folder_path = File.join(gem_root_path, 'spec')
    run_path = File.join(spec_folder_path, 'test_runs', "run_#{Time.now.strftime("%Y%m%d_%H%M%S")}")
    osm_path = File.join(spec_folder_path, 'seed_models/example_small_office.osm')
    epw_path = File.join(spec_folder_path, 'seed_models/Chicago_TMY3.epw')

    measures_path = File.join(gem_root_path, 'lib/measures')
    other_example_measures_path = File.join(spec_folder_path, 'seed_models/example_measures')

    # Add your OpenStudio measure directories to the list if you want to use additional measures
    v_measure_paths = [
        measures_path,
        other_example_measures_path
    ]

    successful = test_case(osm_path, epw_path, v_measure_paths, run_path)
    expect(successful).to be true
  end


  it 'should run multiple simulation tests with variability measures' do
    OpenStudio::Extension::Extension::DO_SIMULATIONS = true

    gem_root_path = File.expand_path("../..", Dir.pwd)

    spec_folder_path = File.join(gem_root_path, 'spec')
    run_path = File.join(spec_folder_path, 'test_runs', "run_#{Time.now.strftime("%Y%m%d_%H%M%S")}")
    osm_path = File.join(spec_folder_path, 'seed_models/example_small_office.osm')
    epw_path = File.join(spec_folder_path, 'seed_models/Chicago_TMY3.epw')

    measures_path = File.join(gem_root_path, 'lib/measures')
    other_example_measures_path = File.join(spec_folder_path, 'seed_models/example_measures')

    # Add your OpenStudio measure directories to the list if you want to use additional measures
    v_measure_paths = [
        measures_path,
        other_example_measures_path
    ]

    successful = test_case_multiple(osm_path, epw_path, v_measure_paths, run_path)
    expect(successful).to be true
  end

  def test_case(seed_osm_path, epw_path, v_measure_paths, run_path)

    unless File.directory?(run_path)
      FileUtils.mkdir_p(run_path)
    end

    v_measure_steps_raw = [
        {
            "measure_type" => "OpenStudio",
            "measure_content" => {
                "measure_dir_name" => "DR_Lighting",
                "measure_arguments" => {},
            }
        },
        {
            "measure_type" => "OpenStudio",
            "measure_content" => {
                "measure_dir_name" => "lighting_retrofit",
                "measure_arguments" => {},
            }
        },
        {
            "measure_type" => "EnergyPlus",
            "measure_content" => {
                "measure_dir_name" => "roof_retrofit",
                "measure_arguments" => {},
            }
        },
        {
            "measure_type" => "OpenStudio",
            "measure_content" => {
                "measure_dir_name" => "AddOutputVariable",
                "arguments" => {
                    "variable_name" => "Zone Mean Air Temperature",
                    "reporting_frequency" => "timestep",
                    "key_value" => "*"
                }
            }
        },
        {
            "measure_type" => "OpenStudio",
            "measure_content" => {
                "measure_dir_name" => "AddMeter",
                "arguments" => {
                    "meter_name" => "Electricity:Facility",
                    "reporting_frequency" => "timestep"
                }
            }
        },
        {
            "measure_type" => "Reporting",
            "measure_content" => {
                "measure_dir_name" => "ExportVariabletoCSV",
                "arguments" => {
                    "variable_name" => "Zone Mean Air Temperature",
                    "reporting_frequency" => "Zone Timestep"
                }
            }
        },
        {
            "measure_type" => "Reporting",
            "measure_content" => {
                "measure_dir_name" => "ExportMetertoCSV",
                "arguments" => {
                    "meter_name" => "Electricity:Facility",
                    "reporting_frequency" => "Zone Timestep"
                }
            }
        },
    ]
    v_measure_steps = order_measures(v_measure_steps_raw)

    out_osw_path = File.join(run_path, 'test_run.osw')
    create_workflow(seed_osm_path, epw_path, v_measure_paths, v_measure_steps, out_osw_path)
    runner = OpenStudio::Extension::Runner.new(run_path)
    runner.run_osw(out_osw_path, run_path)

    # Check if simulation is completed successfully
    successful = false
    sql_file = out_osw_path.gsub('in\\.osw', 'eplusout\\.sql')
    puts "Simulation not completed successfully for file: #{out_osw_path}" unless File.exist?(sql_file)
    successful = true if File.exist?(sql_file)
    return successful
  end

  def test_case_multiple(seed_osm_path, epw_path, v_measure_paths, run_path, max_n_parallel_run = 4)

    # Get seed model
    unless File.directory?(run_path)
      FileUtils.mkdir_p(run_path)
    end

    v_osws = []
    # Create workflow 0
    v_measure_steps_raw_0 = [
        {
            "measure_type" => "OpenStudio",
            "measure_content" => {
                "measure_dir_name" => "AddOutputVariable",
                "arguments" => {
                    "variable_name" => "Zone Mean Air Temperature",
                    "reporting_frequency" => "timestep",
                    "key_value" => "*"
                }
            }
        },
        {
            "measure_type" => "OpenStudio",
            "measure_content" => {
                "measure_dir_name" => "AddMeter",
                "arguments" => {
                    "meter_name" => "Electricity:Facility",
                    "reporting_frequency" => "timestep"
                }
            }
        },
        {
            "measure_type" => "Reporting",
            "measure_content" => {
                "measure_dir_name" => "ExportVariabletoCSV",
                "arguments" => {
                    "variable_name" => "Zone Mean Air Temperature",
                    "reporting_frequency" => "Zone Timestep"
                }
            }
        },
        {
            "measure_type" => "Reporting",
            "measure_content" => {
                "measure_dir_name" => "ExportMetertoCSV",
                "arguments" => {
                    "meter_name" => "Electricity:Facility",
                    "reporting_frequency" => "Zone Timestep"
                }
            }
        },
    ]
    v_measure_steps_0 = order_measures(v_measure_steps_raw_0)
    out_osw_path_0 = File.join(run_path, 'test_run_0/t0.osw')
    unless File.directory?(File.dirname(out_osw_path_0))
      FileUtils.mkdir_p(File.dirname(out_osw_path_0))
    end
    create_workflow(seed_osm_path, epw_path, v_measure_paths, v_measure_steps_0, out_osw_path_0)
    v_osws << out_osw_path_0

    # Create workflow 1
    v_measure_steps_raw_1 = [
        {
            "measure_type" => "OpenStudio",
            "measure_content" => {
                "measure_dir_name" => "lighting_retrofit",
                "measure_arguments" => {},
            }
        },
        {
            "measure_type" => "OpenStudio",
            "measure_content" => {
                "measure_dir_name" => "AddOutputVariable",
                "arguments" => {
                    "variable_name" => "Zone Mean Air Temperature",
                    "reporting_frequency" => "timestep",
                    "key_value" => "*"
                }
            }
        },
        {
            "measure_type" => "OpenStudio",
            "measure_content" => {
                "measure_dir_name" => "AddMeter",
                "arguments" => {
                    "meter_name" => "Electricity:Facility",
                    "reporting_frequency" => "timestep"
                }
            }
        },
        {
            "measure_type" => "Reporting",
            "measure_content" => {
                "measure_dir_name" => "ExportVariabletoCSV",
                "arguments" => {
                    "variable_name" => "Zone Mean Air Temperature",
                    "reporting_frequency" => "Zone Timestep"
                }
            }
        },
        {
            "measure_type" => "Reporting",
            "measure_content" => {
                "measure_dir_name" => "ExportMetertoCSV",
                "arguments" => {
                    "meter_name" => "Electricity:Facility",
                    "reporting_frequency" => "Zone Timestep"
                }
            }
        },
    ]
    v_measure_steps_1 = order_measures(v_measure_steps_raw_1)
    out_osw_path_1 = File.join(run_path, 'test_run_1/t1.osw')
    unless File.directory?(File.dirname(out_osw_path_1))
      FileUtils.mkdir_p(File.dirname(out_osw_path_1))
    end
    create_workflow(seed_osm_path, epw_path, v_measure_paths, v_measure_steps_1, out_osw_path_1)
    v_osws << out_osw_path_1

    # Create workflow 2
    v_measure_steps_raw_2 = [
        {
            "measure_type" => "OpenStudio",
            "measure_content" => {
                "measure_dir_name" => "DR_Lighting",
                "measure_arguments" => {},
            }
        },
        {
            "measure_type" => "OpenStudio",
            "measure_content" => {
                "measure_dir_name" => "lighting_retrofit",
                "measure_arguments" => {},
            }
        },
        {
            "measure_type" => "EnergyPlus",
            "measure_content" => {
                "measure_dir_name" => "roof_retrofit",
                "measure_arguments" => {},
            }
        },
        {
            "measure_type" => "OpenStudio",
            "measure_content" => {
                "measure_dir_name" => "AddOutputVariable",
                "arguments" => {
                    "variable_name" => "Zone Mean Air Temperature",
                    "reporting_frequency" => "timestep",
                    "key_value" => "*"
                }
            }
        },
        {
            "measure_type" => "OpenStudio",
            "measure_content" => {
                "measure_dir_name" => "AddMeter",
                "arguments" => {
                    "meter_name" => "Electricity:Facility",
                    "reporting_frequency" => "timestep"
                }
            }
        },
        {
            "measure_type" => "Reporting",
            "measure_content" => {
                "measure_dir_name" => "ExportVariabletoCSV",
                "arguments" => {
                    "variable_name" => "Zone Mean Air Temperature",
                    "reporting_frequency" => "Zone Timestep"
                }
            }
        },
        {
            "measure_type" => "Reporting",
            "measure_content" => {
                "measure_dir_name" => "ExportMetertoCSV",
                "arguments" => {
                    "meter_name" => "Electricity:Facility",
                    "reporting_frequency" => "Zone Timestep"
                }
            }
        },
    ]
    v_measure_steps_2 = order_measures(v_measure_steps_raw_2)
    out_osw_path_2 = File.join(run_path, 'test_run_2/t2.osw')
    unless File.directory?(File.dirname(out_osw_path_2))
      FileUtils.mkdir_p(File.dirname(out_osw_path_2))
    end
    create_workflow(seed_osm_path, epw_path, v_measure_paths, v_measure_steps_2, out_osw_path_2)
    v_osws << out_osw_path_2

    runner = OpenStudio::Extension::Runner.new(run_path)
    runner.run_osws(v_osws, max_n_parallel_run) # Maximum number of parallel run allowed

    # Check if simulation is completed successfully
    successful = false
    sql_file_0 = out_osw_path_0.gsub('in\\.osw', 'eplusout\\.sql')
    sql_file_1 = out_osw_path_1.gsub('in\\.osw', 'eplusout\\.sql')
    sql_file_2 = out_osw_path_2.gsub('in\\.osw', 'eplusout\\.sql')
    successful = true if File.exist?(sql_file_0) && File.exist?(sql_file_1) && File.exist?(sql_file_2)

    return successful
  end


  def order_measures(v_hash_measure_steps)
    v_measure_os = []
    v_measure_ep = []
    v_measure_rp = []
    v_hash_measure_steps.each do |hash_step_raw|
      if hash_step_raw["measure_type"] == "OpenStudio"
        v_measure_os << hash_step_raw["measure_content"]
      elsif hash_step_raw["measure_type"] == "EnergyPlus"
        v_measure_ep << hash_step_raw["measure_content"]
      elsif hash_step_raw["measure_type"] == "Reporting"
        v_measure_rp << hash_step_raw["measure_content"]
      end
    end
    v_measure_steps_ordered = v_measure_os + v_measure_ep + v_measure_rp
    return v_measure_steps_ordered
  end


  def create_workflow(seed_osm_path, weather_file_path, measure_paths, v_measure_steps, out_osw_path)
    hash_osw = {
        "seed_file" => seed_osm_path,
        "weather_file" => weather_file_path,
        "measure_paths" => measure_paths,
        "steps" => v_measure_steps
    }
    File.open(out_osw_path, "w") do |f|
      f.write(JSON.pretty_generate(hash_osw))
    end
  end

  def load_osm(path_str)
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(path_str)
    model = translator.loadModel(path)
    if model.empty?
      raise "Input #{path_str} is not valid, please check."
    else
      model = model.get
    end
    return model
  end

  def create_prototype_model()

    return 42
  end

  def test_demand_response_measures()

    return 42
  end

  def test_retrofit_measures()

    return 42
  end

  def test_faulty_operation_measures()

    return 42
  end


end
