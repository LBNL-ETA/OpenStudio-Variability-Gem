# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class LightingRetrofit < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Lighting Retrofit'
  end

  # human readable description
  def description
    return 'Replace this text with an explanation of what the measure does in terms that can be understood by a general building professional audience (building owners, architects, engineers, contractors, etc.).  This description will be used to create reports aimed at convincing the owner and/or design team to implement the measure in the actual building design.  For this reason, the description may include details about how the measure would be implemented, along with explanations of qualitative benefits associated with the measure.  It is good practice to include citations in the measure if the description is taken from a known source or if specific benefits are listed.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Replace this text with an explanation for the energy modeler specifically. It should explain how the measure is modeled, including any requirements about how the baseline model must be set up, major assumptions, citations of references to applicable modeling resources, etc.  The energy modeler should be able to read this description and understand what changes the measure is making to the model and why these changes are being made.  Because the Modeler Description is written for an expert audience, using common abbreviations for brevity is good practice.'
  end


  def add_light_space_type(model, space, space_type, space_type_light_def)
    # For space type
    # This function creates space specific lights and light_defs based on space_type specific lights and light_defs
    space_type_lpd = space_type_light_def.wattsperSpaceFloorArea.to_f
    space_type_frac_rad = space_type_light_def.fractionRadiant.to_f
    space_type_frac_vis = space_type_light_def.fractionVisible.to_f
    space_type_frac_return_air = space_type_light_def.returnAirFraction.to_f

    # Set space type schedule rule set to space
    space.setDefaultScheduleSet(space_type.defaultScheduleSet.get)

    # New light definition
    new_light_def = OpenStudio::Model::LightsDefinition.new(model)
    new_light_def.setDesignLevelCalculationMethod('Watts/Area', 1, 1)
    new_light_def.setName("New #{space.name.to_s} light definition")
    # new_light_def.setWattsperSpaceFloorArea(111) # Provide default value, allow users to override
    new_light_def.setWattsperSpaceFloorArea(space_type_lpd) # Provide default value, allow users to override
    new_light_def.setFractionRadiant(space_type_frac_rad)
    new_light_def.setFractionVisible(space_type_frac_vis)
    new_light_def.setReturnAirFraction(space_type_frac_return_air)

    # New light
    new_light = OpenStudio::Model::Lights.new(new_light_def)
    new_light.setName("New #{space.name.to_s} light")
    new_light.setSpace(space)

    return new_light
  end


  def add_light_space(space, space_light_def)
    # New light
    new_light = OpenStudio::Model::Lights.new(space_light_def)
    new_light.setName("New #{space.name.to_s} light")
    new_light.setSpace(space)
    return new_light
  end


  def add_light_ems(model, light, light_level_w, light_sch_ems_sensor, retrofit_month = 1, retrofit_day = 1)
    light_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(light, "Lights", "Electric Power Level")
    light_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    light_program.setName("#{light.name.to_s} actuator".gsub("-", ""))
    light_program_body = <<-EMS
      IF (Month >= #{retrofit_month}) && (DayOfMonth >= #{retrofit_day}),
          SET #{light_actuator.name} = #{light_level_w} * #{light_sch_ems_sensor.handle} !- Overwrite light power level (W)
      ENDIF
    EMS
    light_program.setBody(light_program_body)
    return light_program
  end


  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # Add the retrofit month and day choice arguments
    month_chs = OpenStudio::StringVector.new
    ('1'..'12').each { |month_s| month_chs << month_s }
    retrofit_month = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('retrofit_month', month_chs, true)
    retrofit_month.setDisplayName('Month of the year when retrofit takes place')
    retrofit_month.setDefaultValue('7')
    args << retrofit_month

    day_chs = OpenStudio::StringVector.new
    ('1'..'31').each { |day_s| day_chs << day_s }
    retrofit_day = OpenStudio::Measure::OSArgument.makeChoiceArgument('retrofit_day', day_chs, true)
    retrofit_day.setDisplayName('Day of the month when retrofit takes place')
    retrofit_day.setDefaultValue('1')
    args << retrofit_day


    # Add the new lighting power density arguments
    v_space_types = model.getSpaceTypes
    v_space_types.each do |space_type|
      begin
        current_spaces = space_type.spaces
        current_space_type_light = space_type.lights[0]
        unless current_space_type_light.nil?
          current_space_type_light_def = current_space_type_light.lightsDefinition
          current_space_type_lpd = current_space_type_light_def.wattsperSpaceFloorArea.get.round(1)
          arg_temp = OpenStudio::Measure::OSArgument.makeDoubleArgument("new_#{space_type.name.to_s}_lpd", true)
          arg_temp.setDisplayName("New lighting power density for #{space_type.name.to_s} (W/m2), original value = #{current_space_type_lpd} (W/m2)")
          arg_temp.setDefaultValue(current_space_type_lpd*0.7)
          args << arg_temp
        end
      rescue
      end
    end

    ## Then check light definition by space
    v_spaces = model.getSpaces
    v_spaces.each do |space|
      current_space_light = space.lights[0]
      unless current_space_light.nil?
        current_space_light_def = current_space_light.lightsDefinition
        current_space_lpd = current_space_light_def.wattsperSpaceFloorArea.get.round(1)
        arg_temp = OpenStudio::Measure::OSArgument.makeDoubleArgument("new_#{space.name.to_s}_lpd", true)
        arg_temp.setDisplayName("New electric lighting power density for space: #{space.name.to_s} (W/m2), original value = #{current_space_lpd} (W/m2)")
        arg_temp.setDefaultValue(current_space_lpd*0.7)
        args << arg_temp
      end
    end


    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    retrofit_month = runner.getStringArgumentValue('retrofit_month', user_arguments).to_i
    retrofit_day = runner.getStringArgumentValue('retrofit_day', user_arguments).to_i

    # TODO: check the month and day for reasonableness
    runner.registerInfo("User entered retrofit month: #{retrofit_month}")
    runner.registerInfo("User entered retrofit day: #{retrofit_day}")


    prog_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    prog_calling_manager.setCallingPoint('BeginTimestepBeforePredictor')

    # Remove old and add new light with EMS by spaces
    hash_space_lpd = Hash.new
    v_spaces = model.getSpaces
    v_spaces.each do |space|
      current_space_light = space.lights[0]
      unless current_space_light.nil?
        # Get light power density for each space type
        current_space_lpd = runner.getStringArgumentValue("new_#{space.name.to_s}_lpd", user_arguments)
        hash_space_lpd["new_#{space.name.to_s}_lpd"] = current_space_lpd
        runner.registerInfo("User entered new electric lighting power density for #{space.name.to_s} is #{current_space_lpd} W/m2")

        # Set ems
        current_space_light_def = current_space_light.lightsDefinition
        light_sch_name = current_space_light.schedule.get.nameString

        # light_sch_name = current_space_light_sch_set.nameString
        light_sch_ems_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
        light_sch_ems_sensor.setKeyName(light_sch_name)
        runner.registerInfo("Delete old light object for #{space.name}")
        current_space_light.remove
        new_light = add_light_space(space, current_space_light_def)

        light_level_w = current_space_lpd.to_f * space.floorArea.to_f
        ems_light_program = add_light_ems(model, new_light, light_level_w, light_sch_ems_sensor, retrofit_month, retrofit_day)
        prog_calling_manager.addProgram(ems_light_program)
        runner.registerInfo("Add ems lighting control for #{space.name} succeeded.")
      end
    end


    # Remove old and add new light with EMS by space types
    hash_space_type_lpd = Hash.new
    v_space_types = model.getSpaceTypes
    v_space_types.each do |space_type|
      current_spaces = space_type.spaces
      current_space_type_light = space_type.lights[0]
      unless current_space_type_light.nil?
        # Get lighting power density for each space type
        current_space_type_lpd = runner.getStringArgumentValue("new_#{space_type.name.to_s}_lpd", user_arguments)
        hash_space_type_lpd["new_#{space_type.name.to_s}_lpd"] = current_space_type_lpd
        runner.registerInfo("User entered new lighting power density for #{space_type.name.to_s} is #{current_space_type_lpd} W/m2")
        # Set ems
        current_space_type_light_def = current_space_type_light.lightsDefinition
        current_space_type_sch_set = space_type.defaultScheduleSet.get
        current_space_type_light_sch_set = current_space_type_sch_set.lightingSchedule.get
        light_sch_name = space_type.defaultScheduleSet.get.lightingSchedule.get.nameString
        light_sch_ems_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
        light_sch_ems_sensor.setKeyName(light_sch_name)

        puts "Delete old light object for #{space_type.name}"
        current_space_type_light.remove
        # puts current_space_type_light

        current_spaces.each do |space|

          # Calculate light electric power for each space
          new_light = add_light_space_type(model, space, space_type, current_space_type_light_def)
          light_level_w = current_space_type_lpd.to_f * space.floorArea.to_f
          ems_light_program = add_light_ems(model, new_light, light_level_w, light_sch_ems_sensor, retrofit_month, retrofit_day)
          prog_calling_manager.addProgram(ems_light_program)
          runner.registerInfo("Add ems lighting control for #{space.name} succeeded.")
        end
      end
    end


    # report initial condition of model
    runner.registerInitialCondition("Measure started successfully.")

    # echo the model updates back to the user
    runner.registerInfo("The lighting retrofit measure is applied.")

    # report final condition of model
    runner.registerFinalCondition("Measure ended successfully.")

    return true
  end
end

# register the measure to be used by the application
LightingRetrofit.new.registerWithApplication
