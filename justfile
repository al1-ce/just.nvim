# just reference: https://just.systems/man/en/
# cheatsheet: https://cheatography.com/linux-china/cheat-sheets/justfile/
# monolith flavor: ~/.config/nvim/readme/build.md

# Allows positional arguments
set positional-arguments

# Build justbuild.ts
build:
    tstl -p tsconfig.json

# This is a default recipe
# Tf "default" recipe is not there then
# first recipe will be considered default
#
# Prints all available recipes
# default:
#     @just --list
#
# Here's a quick cheatsheet/overview of just and monoltih flavor
# Monolith \bb, \br, \bt behavor (\bB will show all)
# build - will be default build task "\bb"
# run - will be default run task "\br"
# test - will be default test task "\bt"
#
# Just:
# Set a variable (variable case is arbitrary)
# SINGLE := "--single"
#
# Join paths:
# myPaths := "path/to" / "file" + ".txt"
#
# Or conditions
# foo := if "2" == "2" { "Good!" } else { "1984" }
#
# Run set configurations
# all: build_d build_d_custom _echo
#
# Alias to a recipe (just noecho)
# alias noecho := _echo
#
# Example configuration (dub build not going to be printed):
# build_d:
#     @dub build
#
# Or use this to silence all command prints (output will still print):
# @build_d_custom:
#     dub build
#     dub run
#
# Continue even on fail  by adding "-" ([linux] makes recipe be seen only in linux)
# [linux]
# test:
#    -cat notexists.txt
#    echo "Still executes"
#
# Configuration using variable from above
# buildFile FILENAME:
#     dub build {{SINGLE}} $1
#
# Set env
# @test_d:
#     #!/bin/bash
#     ./test.sh
#
# Private task
# _echo:
#     echo "From echo"
#
# A command's arguments can be passed to dependency
# build target:
#     @echo "Building {{target}}…"
#
# push target: (build target)
#     @echo 'Pushing {{target}}…'
#
# Use `` to eval command, () to join paths
# in them and arg=default to set default value
# test target test=`echo "default"`:
#     @echo 'Testing {{target}} {{test}}'
#
# Use + (1 ore more) or * (0 or more) to make argument variadic. Must be last
# ntest +FILES="justfile1 justfile2":
#     echo "{{FILES}}"
#
# Dependencies always run before recipe, unless they're after &&
# This example will run "a" before "b" and "c" and "d" after "b"
# b: a && c d:
#     echo "b"
#
# Each recipe line is executed by a new shell,
# so if you change the working directory on one line,
# it won't have an effect on later lines.
# A safe way to work around this is to use shebang ("#!/bin/bash")
# foo:
#     pwd    # This `pwd` will print the same directory…
#     cd bar
#     pwd    # …as this `pwd`!


