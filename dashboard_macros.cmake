#  Copyright (c) 2017-2018 John Biddiscombe
#
#  Distributed under the Boost Software License, Version 1.0. (See accompanying
#  file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# ----------------------------------------------
# These macros are just for syntax completeness
# ----------------------------------------------
macro(PYCICLE_CMAKE_OPTION option values)
endmacro(PYCICLE_CMAKE_OPTION)

macro(PYCICLE_CMAKE_DEPENDENT_OPTION option values)
endmacro(PYCICLE_CMAKE_DEPENDENT_OPTION)

# ----------------------------------------------
# Remove outer quotes from string which may contain quotes
# ----------------------------------------------
macro(STRING_UNQUOTE var str)
    # ';' and '\' are tricky, need to be encoded.
    # '\' => '#B'
    # '#' => '#H'
    # ';' => '#S'
    string(REGEX REPLACE "#" "#H" _ret "${str}")
    string(REGEX REPLACE "\\\\" "#B" _ret "${_ret}")
    string(REGEX REPLACE ";" "#S" _ret "${_ret}")

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
    string(REGEX REPLACE "#B" "\\\\" _ret "${_ret}")
    string(REGEX REPLACE "#H" "#" _ret "${_ret}")
    string(REGEX REPLACE "#S" "\\\\;" ${var} "${_ret}")
endmacro(STRING_UNQUOTE var str)

# ----------------------------------------------
# To convert PYCICLE_CMAKE_OPTIONS into individual options flags
# ----------------------------------------------
macro(expand_pycicle_cmake_options option_string)
    #message("The option string is \n${option_string}\n")
    STRING_UNQUOTE(unquoted_string ${option_string})
    #message("The unquoted option string is \n${unquoted_string}\n")

    set( option_args "${unquoted_string}" )
    separate_arguments(option_args)
    foreach(str ${option_args})
        # replace -DVARNAME="stuff" with VARNAME
        string(REGEX REPLACE "-D(.*)=(.*)" "\\1"  arg_name "${str}")
        # replace -DVARNAME="stuff" with "stuff"
        string(REGEX REPLACE ".*=(.*)"     "\\1"  value    "${str}")
        # replace "val{stuff}" with "${stuff}"
        string(REGEX REPLACE "val({.*})"   "$\\1" value2   "${value}")
        # remove quotes from final variable value
        STRING_UNQUOTE(unquoted_value ${value2})
        # assign the value to an actual variable of the correct name
        set(${arg_name} ${unquoted_value})
        message("The value of ${arg_name} is ${unquoted_value} (from ${value2})")
    endforeach()
endmacro(expand_pycicle_cmake_options)
