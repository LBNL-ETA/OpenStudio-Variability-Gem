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

  it 'should run test file with variability measures' do
    OpenStudio::Extension::Extension::DO_SIMULATIONS = true
    test_case
    expect(true).to be true
  end

  def test_case()
    puts '-=' * 30
    # Get seed model
    root_dir = Dir.getwd
    osm_path = File.join(root_dir, 'so_n.osm')
    # model = load_osm(File.join(Dir.getwd, 'so_n.osm'))
    weather_file_path = "C:/Users/hanli/Dropbox (Energy Technologies)/Projects/LDRD-simulation/EPWs/SF_AMY/SF_1988.epw"
    seed_osm_path = osm_path
    v_measure_paths = ["E:/Users/Han/Documents/GitHub/OpenStudio_related/OS-measures"]
    v_measure_steps = [
        {
            "measure_dir_name" => "AddOutputVariable",
            "arguments" => {
                "variable_name" => "Zone Mean Air Temperature",
                "reporting_frequency" => "timestep",
                "key_value" => "*"
            }
        },
        {
            "measure_dir_name" => "lighting_retrofit",
            "arguments" => {}
        },
        {
            "measure_dir_name" => "roof_retrofit",
            "arguments" => {}
        },
        {
            "measure_dir_name" => "ExportVariabletoCSV",
            "arguments" => {
                "variable_name" => "Zone Mean Air Temperature",
                "reporting_frequency" => "Zone Timestep"
            }
        },
    ]
    out_osw_path = File.join(Dir.getwd, 'test.osw')
    create_workflow(seed_osm_path, weather_file_path, v_measure_paths, v_measure_steps, out_osw_path)

    runner = OpenStudio::Extension::Runner.new(root_dir)
    runner.run_osw(out_osw_path, File.join(root_dir, 'temp'))
      # puts runner.methods
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
