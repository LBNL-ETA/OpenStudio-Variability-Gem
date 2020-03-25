# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class EquipmentRetrofit < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Equipment Retrofit'
  end

  # human readable description
  def description
    return 'Replace this text with an explanation of what the measure does in terms that can be understood by a general building professional audience (building owners, architects, engineers, contractors, etc.).  This description will be used to create reports aimed at convincing the owner and/or design team to implement the measure in the actual building design.  For this reason, the description may include details about how the measure would be implemented, along with explanations of qualitative benefits associated with the measure.  It is good practice to include citations in the measure if the description is taken from a known source or if specific benefits are listed.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Replace this text with an explanation for the energy modeler specifically.  It should explain how the measure is modeled, including any requirements about how the baseline model must be set up, major assumptions, citations of references to applicable modeling resources, etc.  The energy modeler should be able to read this description and understand what changes the measure is making to the model and why these changes are being made.  Because the Modeler Description is written for an expert audience, using common abbreviations for brevity is good practice.'
  end


  def add_equip(model, space, space_type, space_type_equip_def)
    # This function creates space specific equip and equip_defs based on space_type specific equip and equip_defs
    space_type_epd = space_type_equip_def.wattsperSpaceFloorArea.to_f

    # Set space type schedule rule set to space
    space.setDefaultScheduleSet(space_type.defaultScheduleSet.get)

    # New equip definition
    new_equip_def = OpenStudio::Model::ElectricEquipmentDefinition.new(model)
    new_equip_def.setDesignLevelCalculationMethod('Watts/Area', 1, 1)
    new_equip_def.setName("New #{space.name.to_s} equip definition")
    new_equip_def.setWattsperSpaceFloorArea(space_type_epd) # Provide default value, allow users to override

    # New equip
    new_equip = OpenStudio::Model::ElectricEquipment.new(new_equip_def)
    new_equip.setName("New #{space.name.to_s} equip")
    new_equip.setSpace(space)

    return new_equip
  end

  def add_equip_ems(model, equip, equip_level_w, equip_sch_ems_sensor, retrofit_month=1, retrofit_day=1)
    equip_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(equip, "ElectricEquipment", "Electric Power Level")
    equip_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    equip_program.setName("#{equip.name.to_s} actuator")
    equip_program_body = <<-EMS
      IF (Month >= #{retrofit_month}) && (DayOfMonth >= #{retrofit_day}),
          SET #{equip_actuator.name} = #{equip_level_w} * #{equip_sch_ems_sensor.handle} !- Overwrite equipment power level (W)
      ENDIF
    EMS
    equip_program.setBody(equip_program_body)
    return equip_program
  end



  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # Add the retrofit month and day choice arguments
    month_chs = OpenStudio::StringVector.new
    ('1'..'12').each {|month_s| month_chs << month_s}
    retrofit_month = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('retrofit_month', month_chs, true)
    retrofit_month.setDisplayName('Month of the year when retrofit takes place')
    retrofit_month.setDefaultValue('7')
    args << retrofit_month

    day_chs = OpenStudio::StringVector.new
    ('1'..'31').each {|day_s| day_chs << day_s}
    retrofit_day = OpenStudio::Measure::OSArgument.makeChoiceArgument('retrofit_day', day_chs, true)
    retrofit_day.setDisplayName('Day of the month when retrofit takes place')
    retrofit_day.setDefaultValue('1')
    args << retrofit_day


    # Add the new equipment power density arguments
    v_space_types = model.getSpaceTypes
    v_space_types.each do |space_type|
      current_spaces = space_type.spaces
      current_space_type_equip = space_type.electricEquipment[0]
    
      unless current_space_type_equip.nil?    
        current_space_type_equip_def = current_space_type_equip.electricEquipmentDefinition
        current_space_type_epd = current_space_type_equip_def.wattsperSpaceFloorArea.get.round(1)
        arg_temp = OpenStudio::Measure::OSArgument.makeDoubleArgument("new_#{space_type.name.to_s}_epd", true)
        arg_temp.setDisplayName("New electric equipment power density for #{space_type.name.to_s} (W/m2)")
        arg_temp.setDefaultValue(current_space_type_epd)
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


    hash_space_type_epd = Hash.new
    v_space_types = model.getSpaceTypes
    v_space_types.each do |space_type|

      current_spaces = space_type.spaces
      current_space_type_equip = space_type.electricEquipment[0]

      unless current_space_type_equip.nil?
        # Get equipment power density for each space type
        current_space_type_epd = runner.getStringArgumentValue("new_#{space_type.name.to_s}_epd", user_arguments)
        hash_space_type_epd["new_#{space_type.name.to_s}_lpd"] = current_space_type_epd
        runner.registerInfo("User entered new electric equipment power density for #{space_type.name.to_s} is #{current_space_type_epd} W/m2")
        
        # Set ems
        current_space_type_equip_def = current_space_type_equip.electricEquipmentDefinition

        current_space_type_sch_set = space_type.defaultScheduleSet.get
        current_space_type_equip_sch_set = current_space_type_sch_set.electricEquipmentSchedule.get

        equip_sch_name = current_space_type_equip_sch_set.nameString
        equip_sch_ems_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, 'Schedule Value')
        equip_sch_ems_sensor.setKeyName(equip_sch_name)

        puts "Delete old equip object for #{space_type.name}"
        current_space_type_equip.remove

        current_spaces.each do |space|
          # Calculate equipemtn electric power for each space
          new_equip = add_equip(model, space, space_type, current_space_type_equip_def)
          equip_level_w = current_space_type_epd.to_f * space.floorArea.to_f
          ems_equip_program = add_equip_ems(model, new_equip, equip_level_w, equip_sch_ems_sensor, retrofit_month, retrofit_day)
          prog_calling_manager.addProgram(ems_equip_program)
          runner.registerInfo("Add ems equipment control for #{space.name} succeeded.")
        end
      

      end
    end




    # report initial condition of model
    runner.registerInitialCondition("Measure started successfully.")

    # echo the model updates back to the user
    runner.registerInfo("The electric equipment retrofit measure is applied.")

    # report final condition of model
    runner.registerFinalCondition("Measure ended successfully.")

    return true
  end
end

# register the measure to be used by the application
EquipmentRetrofit.new.registerWithApplication
