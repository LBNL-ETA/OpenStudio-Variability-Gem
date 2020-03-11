# insert your copyright here

require 'yaml'

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class ExteriorWallRetrofit < OpenStudio::Measure::EnergyPlusMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Exterior Wall Retrofit'
  end

  # human readable description
  def description
    return 'This measure increase the thermal resistance of the exterior wall by adding a movable insulation at user specified date.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'This measure increase the thermal resistance of the exterior wall by adding a movable insulation at user specified date.'
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Measure::OSArgumentVector.new

    # 1. Require user input for adding a new material for surface control
    ## Roughness
    roughness_chs = OpenStudio::StringVector.new
    roughness_chs << "VeryRough"
    roughness_chs << "Rough"
    roughness_chs << "MediumRough"
    roughness_chs << "MediumSmooth"
    roughness_chs << "Smooth"
    roughness_chs << "VerySmooth"

    arg_material_roughness = OpenStudio::Measure::OSArgument.makeChoiceArgument('material_roughness', roughness_chs, true)
    arg_material_roughness.setDisplayName('Choose new wall insulation material roughness')
    arg_material_roughness.setDefaultValue('Smooth')

    ## Thickness
    arg_thermal_resistance = OpenStudio::Measure::OSArgument.makeDoubleArgument('material_thermal_resistance', true)
    arg_thermal_resistance.setDisplayName('Thermal Resistance (m2-K/W)')
    arg_thermal_resistance.setDefaultValue(1.25)

    ## Thermal Absorptance
    arg_thermal_absorptance = OpenStudio::Measure::OSArgument.makeDoubleArgument('material_thermal_absorptance', true)
    arg_thermal_absorptance.setDisplayName('Thermal Absorptance')
    arg_thermal_absorptance.setDefaultValue(0.84)

    ## Solar Absorptance
    arg_solar_absorptance = OpenStudio::Measure::OSArgument.makeDoubleArgument('material_solar_absorptance', true)
    arg_solar_absorptance.setDisplayName('Solar Absorptance')
    arg_solar_absorptance.setDefaultValue(0.75)

    ## Visible Absorptance
    arg_visible_absorptance = OpenStudio::Measure::OSArgument.makeDoubleArgument('material_visible_absorptance', true)
    arg_visible_absorptance.setDisplayName('Visible Absorptance')
    arg_visible_absorptance.setDefaultValue(0.75)

    args << arg_material_roughness
    args << arg_thermal_resistance
    args << arg_thermal_absorptance
    args << arg_solar_absorptance
    args << arg_visible_absorptance

    # 4. Add where to add the insulation argument
    insulation_type_chs = OpenStudio::StringVector.new
    insulation_type_chs << 'Inside'
    #insulation_type_chs << 'Outside' # Put the insulation outside will impact the sizing?
    arg_insulation_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('insulation_type', insulation_type_chs, true)
    arg_insulation_type.setDisplayName('Add to exterior or interior of the surface')
    arg_insulation_type.setDefaultValue('Inside')
    args << arg_insulation_type

    # 3. Add the retrofit month and day choice arguments
    month_chs = OpenStudio::StringVector.new
    ('1'..'12').each { |month_s| month_chs << month_s }
    arg_retrofit_month = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('retrofit_month', month_chs, true)
    arg_retrofit_month.setDisplayName('Month of the year when retrofit takes place')
    arg_retrofit_month.setDefaultValue('7')
    args << arg_retrofit_month

    day_chs = OpenStudio::StringVector.new
    ('1'..'31').each { |day_s| day_chs << day_s }
    arg_retrofit_day = OpenStudio::Measure::OSArgument.makeChoiceArgument('retrofit_day', day_chs, true)
    arg_retrofit_day.setDisplayName('Day of the month when retrofit takes place')
    arg_retrofit_day.setDefaultValue('1')
    args << arg_retrofit_day

    # 4. List all exterior walls for user to decide whether or not to add movable insulation
    v_ws_building_surface = workspace.getObjectsByType('BuildingSurface:Detailed'.to_IddObjectType)
    v_ws_building_surface.each do |ws_surface|
      surface_name = ws_surface.getField(0).get
      surface_type = ws_surface.getField(1).get
      # Only add walls to the list
      if surface_type == 'Wall'
        arg = OpenStudio::Measure::OSArgument.makeBoolArgument(surface_name, true)
        arg.setDisplayName("Apply to #{surface_name}")
        arg.setDefaultValue(true)
        args << arg
      end
    end

    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      return false

    end

    runner.registerInfo('Start to read user arguments.')
    # Get user input arguments
    material_roughness = runner.getStringArgumentValue('material_roughness', user_arguments)
    material_thermal_resistance = runner.getDoubleArgumentValue('material_thermal_resistance', user_arguments)
    material_thermal_absorptance = runner.getDoubleArgumentValue('material_thermal_absorptance', user_arguments)
    material_solar_absorptance = runner.getDoubleArgumentValue('material_solar_absorptance', user_arguments)
    material_visible_absorptance = runner.getDoubleArgumentValue('material_visible_absorptance', user_arguments)
    insulation_type = runner.getStringArgumentValue('insulation_type', user_arguments)
    retrofit_month = runner.getStringArgumentValue('retrofit_month', user_arguments)
    retrofit_day = runner.getStringArgumentValue('retrofit_day', user_arguments)

    retrofit_sch_type_limit_name = 'Wall Retrofit Sch Type - Fraction'
    retrofit_sch_name = 'Wall Retrofit Sch'
    retrofit_material_name = 'Wall Retrofit Material'
    retrofit_ineffective_day_sch_name = 'Wall Retrofit Ineffective Day Schedule'
    retrofit_effective_day_sch_name = 'Wall Retrofit Effective Day Schedule'
    retrofit_ineffective_week_daily_sch_name = "Wall Retrofit Schedule Week Rule - 1/1-#{retrofit_month}/#{retrofit_day}"
    retrofit_effective_week_daily_sch_name = "Wall Retrofit Schedule Week Rule - #{retrofit_month}/#{retrofit_day}-12/31"

    r_month = OpenStudio::MonthOfYear.new(retrofit_month.to_i)
    r_date_effective_before = OpenStudio::Date.new(r_month, retrofit_day.to_i)
    r_date_effective_after = OpenStudio::Date.fromDayOfYear(r_date_effective_before.dayOfYear + 1)

    runner.registerInfo('Getting user arguments completed.')
    # array to hold new IDF objects needed for exterior wall retrofit
    string_objects = []

    runner.registerInfo("Retrofit -- Create new Material object for the movable insulation.")
    string_objects << "
      Material:NoMass,
        #{retrofit_material_name},        !- Name
        #{material_roughness},            !- Roughness
        #{material_thermal_resistance},   !- Thermal Resistance {m2-K/W}
        #{material_thermal_absorptance},  !- Thermal Absorptance
        #{material_solar_absorptance},    !- Solar Absorptance
        #{material_visible_absorptance};  !- Visible Absorptance
    "

    runner.registerInfo("Retrofit -- Create movable insulation schedule based on user input.")
    runner.registerInfo("New insulation layer will be effective on #{retrofit_month}/#{retrofit_day}.")
    string_objects << "
      ScheduleTypeLimits,
          #{retrofit_sch_type_limit_name},   !- Name
          0.0,                     !- Lower Limit Value
          1.0,                     !- Upper Limit Value
          CONTINUOUS;              !- Numeric Type
    "

    string_objects << "
      Schedule:Day:Interval,
          #{retrofit_ineffective_day_sch_name},  !- Name
          #{retrofit_sch_type_limit_name},     !- Schedule Type Limits Name
          No,                      !- Interpolate to Timestep
          24:00,                   !- Time 1 {hh:mm}
          0;                       !- Value Until Time 1
    "
    string_objects << "
      Schedule:Day:Interval,
          #{retrofit_effective_day_sch_name},  !- Name
          #{retrofit_sch_type_limit_name},     !- Schedule Type Limits Name
          No,                      !- Interpolate to Timestep
          24:00,                   !- Time 1 {hh:mm}
          1;                       !- Value Until Time 1
    "

    string_objects << "
      ! A schedule before retrofit
      Schedule:Week:Daily,
          #{retrofit_ineffective_week_daily_sch_name},  !- Name
          #{retrofit_ineffective_day_sch_name},  !- Sunday Schedule:Day Name
          #{retrofit_ineffective_day_sch_name},  !- Monday Schedule:Day Name
          #{retrofit_ineffective_day_sch_name},  !- Tuesday Schedule:Day Name
          #{retrofit_ineffective_day_sch_name},  !- Wednesday Schedule:Day Name
          #{retrofit_ineffective_day_sch_name},  !- Thursday Schedule:Day Name
          #{retrofit_ineffective_day_sch_name},  !- Friday Schedule:Day Name
          #{retrofit_ineffective_day_sch_name},  !- Saturday Schedule:Day Name
          #{retrofit_ineffective_day_sch_name},  !- Holiday Schedule:Day Name
          #{retrofit_ineffective_day_sch_name},  !- SummerDesignDay Schedule:Day Name
          #{retrofit_ineffective_day_sch_name},  !- WinterDesignDay Schedule:Day Name
          #{retrofit_ineffective_day_sch_name},  !- CustomDay1 Schedule:Day Name
          #{retrofit_ineffective_day_sch_name};  !- CustomDay2 Schedule:Day Name
    "

    string_objects << "
      ! A schedule after retrofit
      Schedule:Week:Daily,
          #{retrofit_effective_week_daily_sch_name},  !- Name
          #{retrofit_effective_day_sch_name},  !- Sunday Schedule:Day Name
          #{retrofit_effective_day_sch_name},  !- Monday Schedule:Day Name
          #{retrofit_effective_day_sch_name},  !- Tuesday Schedule:Day Name
          #{retrofit_effective_day_sch_name},  !- Wednesday Schedule:Day Name
          #{retrofit_effective_day_sch_name},  !- Thursday Schedule:Day Name
          #{retrofit_effective_day_sch_name},  !- Friday Schedule:Day Name
          #{retrofit_effective_day_sch_name},  !- Saturday Schedule:Day Name
          #{retrofit_effective_day_sch_name},  !- Holiday Schedule:Day Name
          #{retrofit_ineffective_day_sch_name},  !- SummerDesignDay Schedule:Day Name
          #{retrofit_ineffective_day_sch_name},  !- WinterDesignDay Schedule:Day Name
          #{retrofit_effective_day_sch_name},  !- CustomDay1 Schedule:Day Name
          #{retrofit_effective_day_sch_name};  !- CustomDay2 Schedule:Day Name
    "

    string_objects << "
      Schedule:Year,
          #{retrofit_sch_name},  !- Name
          #{retrofit_sch_type_limit_name},                !- Schedule Type Limits Name
          #{retrofit_ineffective_week_daily_sch_name},    !- Schedule:Week Name 1
          1,                                              !- Start Month 1
          1,                                              !- Start Day 1
          #{r_date_effective_before.monthOfYear.value},   !- End Month 1
          #{r_date_effective_before.dayOfMonth},          !- End Day 1
          #{retrofit_effective_week_daily_sch_name},      !- Schedule:Week Name 2
          #{r_date_effective_after.monthOfYear.value},    !- Start Month 2
          #{r_date_effective_after.dayOfMonth},           !- Start Day 2
          12,                                             !- End Month 2
          31;                                             !- End Day 2
    "

    # Old: retrofit will impact sizing
    #string_objects << "
    #  Schedule:Compact,
    #    #{retrofit_sch_name}, !- Name
    #    #{retrofit_sch_type_limit_name}, !- Schedule Type Limits Name
    #    Through: #{retrofit_month}/#{retrofit_day}, !- Field 1
    #    For: Alldays,            !- Field 2
    #    Until: 24:00,0.00,       !- Field 3
    #    Through: 12/31,          !- Field 9
    #    For: Alldays,            !- Field 10
    #    Until: 24:00,1.00;       !- Field 11
    #"

    runner.registerInfo("Retrofit -- Create SurfaceControl:MovableInsulation objects for selected walls.")
    v_ws_building_surface = workspace.getObjectsByType('BuildingSurface:Detailed'.to_IddObjectType)
    v_ws_building_surface.each do |ws_surface|
      surface_name = ws_surface.getField(0).get
      surface_type = ws_surface.getField(1).get
      # Only add walls to the list
      if surface_type == 'Wall'
        applicable = runner.getBoolArgumentValue(surface_name, user_arguments)
        if applicable
          string_objects << "
            SurfaceControl:MovableInsulation,
              #{insulation_type},          !- Insulation Type
              #{surface_name},             !- Surface Name
              #{retrofit_material_name},   !- Material Name
              #{retrofit_sch_name};        !- Schedule Name
          "
        end
      end
    end


    runner.registerInfo('Start to create movable insulation for walls.')
    # reporting initial condition of model
    runner.registerInitialCondition("Adding new workspace object...")
    string_objects.each do |string_object|
      idfObject = OpenStudio::IdfObject.load(string_object)
      object = idfObject.get
      wsObject = workspace.addObject(object)
    end


    # report final condition of model
    runner.registerFinalCondition("Adding insulation for exterior wall retrofit completed.")

    return true
  end
end

# register the measure to be used by the application
ExteriorWallRetrofit.new.registerWithApplication
