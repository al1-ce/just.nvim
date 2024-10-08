
#!/usr/bin/env -S just --justfile
# just reference  : https://just.systems/man/en/

@default:
    just --list

build:
    #!/bin/bash
    ls src/ | grep -e ".*\.js" | sed "s/\..*//" | while read line
    do
        echo "--- Compiling $line.js ---"
        js2lua \
            --no-tagArrayExpression \
            --no-index0to1 \
            "src/$line.js" > "lua/just/$line.lua"
    done

