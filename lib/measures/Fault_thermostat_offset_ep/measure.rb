# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/
require 'yaml'
# start the measure
class FaultThermostatOffset < OpenStudio::Measure::EnergyPlusMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Fault_thermostat_offset'
  end

  # human readable description
  def description
    return 'Thermostat offset fault. A positive value means the zone air temperature reading is higher than the actual value. A negative value means the reading is lower than the actual value. A “0.0” value means no offset. Default is 2.0. The units are in degrees Celsius.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Thermostat offset fault. A positive value means the zone air temperature reading is higher than the actual value. A negative value means the reading is lower than the actual value. A “0.0” value means no offset. Default is 2.0. The units are in degrees Celsius.'
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Measure::OSArgumentVector.new

    # 1. Set offset degrees
    arg_offset_degree_c = OpenStudio::Measure::OSArgument.makeDoubleArgument('offset_degree_c', true)
    arg_offset_degree_c.setDisplayName('Thermostat Offset Degrees Celsius')
    arg_offset_degree_c.setDefaultValue(2)
    args << arg_offset_degree_c

    # 2. Add the fault start and end month and day choice arguments
    month_chs = OpenStudio::StringVector.new
    day_chs = OpenStudio::StringVector.new
    ('1'..'12').each { |month_s| month_chs << month_s }
    ('1'..'31').each { |day_s| day_chs << day_s }

    arg_fault_start_month = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('fault_month_s', month_chs, true)
    arg_fault_start_month.setDisplayName('Month of the year when this fault happens')
    arg_fault_start_month.setDefaultValue('3')
    args << arg_fault_start_month

    arg_fault_start_day = OpenStudio::Measure::OSArgument.makeChoiceArgument('fault_day_s', day_chs, true)
    arg_fault_start_day.setDisplayName('Day of the month when this fault happens')
    arg_fault_start_day.setDefaultValue('1')
    args << arg_fault_start_day

    arg_fault_end_month = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('fault_month_e', month_chs, true)
    arg_fault_end_month.setDisplayName('Month of the year when this fault ends')
    arg_fault_end_month.setDefaultValue('5')
    args << arg_fault_end_month

    arg_fault_end_day = OpenStudio::Measure::OSArgument.makeChoiceArgument('fault_day_e', day_chs, true)
    arg_fault_end_day.setDisplayName('Day of the month when this fault ends')
    arg_fault_end_day.setDefaultValue('1')
    args << arg_fault_end_day

    # 3. Specify which thermostat are affected
    v_ws_thermostats = workspace.getObjectsByType('ZoneControl:Thermostat'.to_IddObjectType)
    v_ws_thermostats.each do |ws_thermostat|
      # puts ws_thermostat
      thermostat_name = ws_thermostat.getField(0).get
      arg = OpenStudio::Measure::OSArgument.makeBoolArgument("#{thermostat_name}_applied", true)
      arg.setDisplayName("Apply to #{thermostat_name}")
      arg.setDefaultValue(true)
      args << arg
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

    # Get user input arguments
    arg_offset_degree_c = runner.getDoubleArgumentValue('offset_degree_c', user_arguments)
    arg_fault_start_month = runner.getStringArgumentValue('fault_month_s', user_arguments)
    arg_fault_start_day = runner.getStringArgumentValue('fault_day_s', user_arguments)
    arg_fault_end_month = runner.getStringArgumentValue('fault_month_e', user_arguments)
    arg_fault_end_day = runner.getStringArgumentValue('fault_day_e', user_arguments)

    f_month_s = OpenStudio::MonthOfYear.new(arg_fault_start_month.to_i)
    f_month_e = OpenStudio::MonthOfYear.new(arg_fault_end_month.to_i)
    f_date_activated_before = OpenStudio::Date.new(f_month_s, arg_fault_start_day.to_i)
    f_date_deactivated_before = OpenStudio::Date.new(f_month_e, arg_fault_end_day.to_i)
    f_date_activated_after = OpenStudio::Date.fromDayOfYear(f_date_activated_before.dayOfYear + 1)
    f_date_deactivated_after = OpenStudio::Date.fromDayOfYear(f_date_deactivated_before.dayOfYear + 1)

    fault_sch_name = 'Thermostat Offset Fault Schedule'
    fault_activated_day_sch_name = 'Thermostat Offset Fault activated Day Schedule'
    fault_deactivated_day_sch_name = 'Thermostat Offset Fault deactivated Day Schedule'
    fault_activated_week_daily_sch_name = 'Thermostat Offset Fault activated week daily schedule'
    fault_deactivated_week_daily_sch_name = 'Thermostat Offset Fault deactivated week daily schedule'
    fault_availablitiy_sch_type_limit_name = 'Thermostat Offset Fault Sch Type - Fraction'

    string_objects = []

    # Create needed schedule and schedule type limits
    string_objects << "
      ScheduleTypeLimits,
          #{fault_availablitiy_sch_type_limit_name},    !- Name
          0.0,                                          !- Lower Limit Value
          1.0,                                          !- Upper Limit Value
          CONTINUOUS;                                   !- Numeric Type
    "

    string_objects << "
      Schedule:Day:Interval,
          #{fault_deactivated_day_sch_name},              !- Name
          #{fault_availablitiy_sch_type_limit_name},      !- Schedule Type Limits Name
          No,                                             !- Interpolate to Timestep
          24:00,                                          !- Time 1 {hh:mm}
          0;                                              !- Value Until Time 1
    "

    string_objects << "
      Schedule:Day:Interval,
          #{fault_activated_day_sch_name},                !- Name
          #{fault_availablitiy_sch_type_limit_name},      !- Schedule Type Limits Name
          No,                                             !- Interpolate to Timestep
          24:00,                                          !- Time 1 {hh:mm}
          1;                                              !- Value Until Time 1
    "

    string_objects << "
      ! A schedule before retrofit
      Schedule:Week:Daily,
          #{fault_deactivated_week_daily_sch_name},   !- Name
          #{fault_deactivated_day_sch_name},          !- Sunday Schedule:Day Name
          #{fault_deactivated_day_sch_name},          !- Monday Schedule:Day Name
          #{fault_deactivated_day_sch_name},          !- Tuesday Schedule:Day Name
          #{fault_deactivated_day_sch_name},          !- Wednesday Schedule:Day Name
          #{fault_deactivated_day_sch_name},          !- Thursday Schedule:Day Name
          #{fault_deactivated_day_sch_name},          !- Friday Schedule:Day Name
          #{fault_deactivated_day_sch_name},          !- Saturday Schedule:Day Name
          #{fault_deactivated_day_sch_name},          !- Holiday Schedule:Day Name
          #{fault_deactivated_day_sch_name},          !- SummerDesignDay Schedule:Day Name
          #{fault_deactivated_day_sch_name},          !- WinterDesignDay Schedule:Day Name
          #{fault_deactivated_day_sch_name},          !- CustomDay1 Schedule:Day Name
          #{fault_deactivated_day_sch_name};          !- CustomDay2 Schedule:Day Name
    "

    string_objects << "
      ! A schedule after retrofit
      Schedule:Week:Daily,
          #{fault_activated_week_daily_sch_name},   !- Name
          #{fault_activated_day_sch_name},          !- Sunday Schedule:Day Name
          #{fault_activated_day_sch_name},          !- Monday Schedule:Day Name
          #{fault_activated_day_sch_name},          !- Tuesday Schedule:Day Name
          #{fault_activated_day_sch_name},          !- Wednesday Schedule:Day Name
          #{fault_activated_day_sch_name},          !- Thursday Schedule:Day Name
          #{fault_activated_day_sch_name},          !- Friday Schedule:Day Name
          #{fault_activated_day_sch_name},          !- Saturday Schedule:Day Name
          #{fault_activated_day_sch_name},          !- Holiday Schedule:Day Name
          #{fault_deactivated_day_sch_name},        !- SummerDesignDay Schedule:Day Name
          #{fault_deactivated_day_sch_name},        !- WinterDesignDay Schedule:Day Name
          #{fault_activated_day_sch_name},          !- CustomDay1 Schedule:Day Name
          #{fault_activated_day_sch_name};          !- CustomDay2 Schedule:Day Name
    "

    string_objects << "
      Schedule:Year,
          #{fault_sch_name},  !- Name
          #{fault_availablitiy_sch_type_limit_name},        !- Schedule Type Limits Name
          #{fault_deactivated_week_daily_sch_name},         !- Schedule:Week Name 1
          1,                                                !- Start Month 1
          1,                                                !- Start Day 1
          #{f_date_activated_before.monthOfYear.value},     !- End Month 1
          #{f_date_activated_before.dayOfMonth},            !- End Day 1
          #{fault_activated_week_daily_sch_name},           !- Schedule:Week Name 2
          #{f_date_activated_after.monthOfYear.value},      !- Start Month 2
          #{f_date_activated_after.dayOfMonth},             !- Start Day 2
          #{f_date_deactivated_before.monthOfYear.value},   !- End Month 2
          #{f_date_deactivated_before.dayOfMonth},          !- End Day 2
          #{fault_deactivated_week_daily_sch_name},         !- Schedule:Week Name 3
          #{f_date_deactivated_after.monthOfYear.value},    !- Start Month 3
          #{f_date_deactivated_after.dayOfMonth},           !- Start Day 3
          12,                                               !- End Month 3
          31;                                               !- End Day 3
    "

    v_ws_thermostats = workspace.getObjectsByType('ZoneControl:Thermostat'.to_IddObjectType)
    v_ws_thermostats.each do |ws_thermostat|
      thermostat_name = ws_thermostat.getField(0).get
      arg_temp = runner.getStringArgumentValue("#{thermostat_name}_applied", user_arguments)
      if arg_temp
        string_objects << "
          FaultModel:ThermostatOffset,
            #{thermostat_name}_offset fault,    !- Name
            #{thermostat_name},                 !- Thermostat Name
            #{fault_sch_name},                  !- Availability Schedule Name
            ,                                   !- Severity Schedule Name
            #{arg_offset_degree_c};             !- Reference Thermostat Offset {deltaC}
        "
      end
    end

    string_objects.each do |string_object|
      idfObject = OpenStudio::IdfObject.load(string_object)
      object = idfObject.get
      wsObject = workspace.addObject(object)
    end
    # echo the new zone's name back to the user, using the index based getString method
    runner.registerInfo("A zone named ")

    # report final condition of model
    runner.registerFinalCondition("The building finished with ")

    return true
  end
end

# register the measure to be used by the application
FaultThermostatOffset.new.registerWithApplication
