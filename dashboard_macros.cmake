#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# ----------------------------------------------
# These macros are just for syntax completeness
# ----------------------------------------------
macro(PYCICLE_CMAKE_OPTION option dummy)
endmacro(PYCICLE_CMAKE_OPTION)

macro(PYCICLE_CMAKE_DEPENDENT_OPTION dummy)
endmacro(PYCICLE_CMAKE_DEPENDENT_OPTION)

macro(PYCICLE_CMAKE_BOOLEAN_OPTION)
endmacro(PYCICLE_CMAKE_BOOLEAN_OPTION)

# ----------------------------------------------
# For debug output
# ----------------------------------------------
set(PYCICLE_LINE_STRING
    "# ----------------------------------------------\n")

# ----------------------------------------------
# This provides a ton of feedback from ctest if needed, but it's too much for normal
# use, so enable it manually to see trace information from ctest submit etc
# ----------------------------------------------
#set(EXTRA_CTEST_DEBUG "--debug")

# ----------------------------------------------
# Print message if in debug mode
# ----------------------------------------------
function(debug_message)
  if(PYCICLE_DEBUG_MODE)
    message("${ARGN}")
  endif()
endfunction()

# ----------------------------------------------
# Submit to the dashboard unless in debug mode
# ----------------------------------------------
macro(pycicle_submit)
    debug_message("Calling ctest_submit with ${ARGN}")
#  if(NOT PYCICLE_DEBUG_MODE)
    ctest_submit(${ARGN}
        RETURN_VALUE result
        CAPTURE_CMAKE_ERROR error)
    if(result)
        message(FATAL_ERROR "Submit step ${ARGN} failed\n${error}")
    else()
        message("Submit step ${ARGN} success\n${error}")
    endif()
#  endif()
endmacro()

# ----------------------------------------------
# execute_process with debug messages
# ----------------------------------------------
function(debug_execute_process)
  set(options FATAL)
  set(oneValueArgs WORKING_DIRECTORY TITLE MESSAGE)
  set(multiValueArgs COMMAND)
  cmake_parse_arguments(DEX "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )
  debug_message(
      "execute_process : ${DEX_TITLE}\n\t"
      "[WORKING_DIRECTORY] ${DEX_WORKING_DIRECTORY}\n\t"
      "[COMMAND] ${DEX_COMMAND}")
  execute_process(
    COMMAND            ${DEX_COMMAND}
    WORKING_DIRECTORY "${DEX_WORKING_DIRECTORY}"
    #COMMAND_ECHO STDOUT (requires cmake 3.15)
    OUTPUT_VARIABLE output
    ERROR_VARIABLE  error
    RESULT_VARIABLE failed
  )
  if (failed EQUAL 1)
    if (DEX_FATAL)
      set(IS_FATAL "FATAL_ERROR")
    endif()
    message(${IS_FATAL} "${DEX_TITLE}${PYCICLE_LINE_STRING}${DEX_MESSAGE} \n"
        "Output is \n${output}${PYCICLE_LINE_STRING}"
        "Error  is \n${error}${PYCICLE_LINE_STRING}")
  else()
      message("${DEX_TITLE} : execute_process : SUCCESS")
      debug_message("Output is \n${output}${PYCICLE_LINE_STRING}")
  endif()
endfunction()

# ----------------------------------------------
# Remove outer quotes from string which may contain quotes
# ----------------------------------------------
macro(STRING_UNQUOTE var str)
    # ';' and '\' are tricky, need to be encoded.
    # '\' => '#B'
    # '#' => '#H'
    # ';' => '#S'
    string(REGEX REPLACE "#"    "#H" _ret "${str}")
    string(REGEX REPLACE "\\\\" "#B" _ret "${_ret}")
    string(REGEX REPLACE ";"    "#S" _ret "${_ret}")

    if(_ret MATCHES "^[ \t\r\n]+")
        string(REGEX REPLACE "^[ \t\r\n]+" "" _ret "${_ret}")
    endif(_ret MATCHES "^[ \t\r\n]+")
    if(_ret MATCHES "^\"")
        # Double quote
        string(REGEX REPLACE "\"\(.*\)\"[ \t\r\n]*$" "\\1" _ret "${_ret}")
    elseif(_ret MATCHES "^'")
        # Single quote
        string(REGEX REPLACE "'\(.*\)'[ \t\r\n]*$" "\\1" _ret "${_ret}")
    else(_ret MATCHES "^\"")
        set(_ret "")
    endif(_ret MATCHES "^\"")

    # Unencoding
    string(REGEX REPLACE "#B" "\\\\"  _ret   "${_ret}")
    string(REGEX REPLACE "#H" "#"     _ret   "${_ret}")
    string(REGEX REPLACE "#S" "\\\\;" ${var} "${_ret}")
endmacro(STRING_UNQUOTE var str)

# ----------------------------------------------
# To convert PYCICLE_CMAKE_OPTIONS into individual options flags
# ----------------------------------------------
macro(expand_pycicle_cmake_options option_string)
    debug_message("The option string is \n${option_string}\n")
    STRING_UNQUOTE(unquoted_string ${option_string})
    if (unquoted_string STREQUAL "")
        set(unquoted_string ${option_string})
    endif()
    debug_message("The unquoted option string is \n${unquoted_string}\n")

    separate_arguments(separated_args UNIX_COMMAND "${unquoted_string}")
    debug_message("Separated args are \n${separated_args}\n")

    foreach(str ${separated_args})
        # replace -DVARNAME="stuff" with VARNAME
        string(REGEX REPLACE "-D(.*)=(.*)" "\\1"  arg_name "${str}")
        # debug_message("Pass 1 " ${arg_name})
        # replace -DVARNAME="stuff" with "stuff"
        string(REGEX REPLACE ".*=(.*)"     "\\1"  value    "${str}")
        # message("Pass 2 " ${value})
        # replace "val{stuff}" with "${stuff}"
        string(REGEX REPLACE "val({.*})"   "$\\1" value2   "${value}")
        # message("Pass 3 " ${value2})
        # remove quotes from final variable value if it doesn't have spaces
        if (value2 MATCHES " ")
            set(unquoted_value ${value2})
        elseif (value2 MATCHES "\"")
            STRING_UNQUOTE(unquoted_value ${value2})
        else ()
            set(unquoted_value ${value2})
        endif()
        # message("Pass 4 " ${unquoted_value})
        # assign the value to an actual variable of the correct name
        set(${arg_name} ${unquoted_value})
        debug_message("The value of ${arg_name} is ${unquoted_value} (from ${value2})")
    endforeach()
endmacro(expand_pycicle_cmake_options)
