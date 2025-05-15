#!/bin/bash
export SCRIPT_DIRECTORY=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export BUILD_DIRECTORY_NAME='out'
export TESTS_DIRECTORY_NAME='tests'
export BUILD_DIRECTORY="$SCRIPT_DIRECTORY/$BUILD_DIRECTORY_NAME"
export TESTS_DIRECTORY="$SCRIPT_DIRECTORY/$TESTS_DIRECTORY_NAME"

export BUILD_C_FLAGS="-fopenmp -flto=jobserver -std=gnu99 -march=native -ffunction-sections -fdata-sections -fPIC -fopenmp-simd -fno-ident -fshort-enums -Wall -Wextra"
export BUILD_C_FLAGS_DEBUG="-Og -ggdb"
export BUILD_C_FLAGS_TESTS="$BUILD_C_FLAGS_DEBUG"

export declare BUILD_DEFINES=(
)

export declare BUILD_DEFINES_DEBUG=(
    "DEBUG"
)

export declare BUILD_INCLUDES=(
    "stdfunc/include"
)

export declare BUILD_INCLUDES_TESTS=(
    "test/include"
)

export LINK_FLAGS="-fopenmp -flto -fPIC -fuse-ld=mold -Wl,-O1 -Wl,--gc-sections -Wl,--no-eh-frame-hdr"
export LINK_FLAGS_DEBUG="-ggdb"
export LINK_FLAGS_TESTS="$LINK_FLAGS_DEBUG"

export declare LIBRARIES_TO_LINK_TESTS=(
    'm'
)
export C_COMPILER="ccache gcc"
export EXECUTABLE_NAME="main.out"
export EXECUTABLE_NAME_TESTS="$EXECUTABLE_NAME"'_test'

export readonly GREEN_LIGHT_COLOR='\e[1;32m'
export readonly YELLOW_COLOR='\e[1;33m'
export readonly BLUE_LIGHT_COLOR='\e[1;34m'
export readonly PURPLE_LIGHT_COLOR='\e[1;35m'
export readonly CYAN_LIGHT_COLOR='\e[1;36m'
export readonly RESET_COLOR='\e[0m'

export BUILD_TYPE_COLOR="$PURPLE_LIGHT_COLOR"
export DEFINES_COLOR="$CYAN_LIGHT_COLOR"
export INCLUDES_COLOR="$BLUE_LIGHT_COLOR"
export LIBRARIES_COLOR="$BLUE_LIGHT_COLOR"
export PARTS_TO_BUILD_COLOR="$YELLOW_COLOR"
export BUILT_EXECUTABLE_COLOR="$GREEN_LIGHT_COLOR"

clear

source './config.sh' && {

command -v $C_COMPILER >/dev/null 2>&1 || { echo "$C_COMPILER not found"; exit 1; }
command -v fd  >/dev/null 2>&1 || { echo "fd (fd-find) not found"; exit 1; }

mkdir -p "$BUILD_DIRECTORY"

# Remove all object files
fd -I '\.o$' -x rm {}

echo -e "$BUILD_TYPE_COLOR"'Building tests'"$RESET_COLOR"

BUILD_C_FLAGS="$BUILD_C_FLAGS $BUILD_C_FLAGS_TESTS"
LINK_FLAGS="$LINK_FLAGS $LINK_FLAGS_TESTS"
BUILD_DEFINES+=( "${BUILD_DEFINES_DEBUG[@]}" )

if [ ${#BUILD_DEFINES[@]} -ne 0 ]; then
    printf -v definesAsString -- "-D %s " "${BUILD_DEFINES[@]}"
    echo -e "$DEFINES_COLOR""$definesAsString""$RESET_COLOR"
fi

if [ ${#BUILD_INCLUDES[@]} -ne 0 ]; then
    printf -v includesAsString -- "-I $SCRIPT_DIRECTORY/%s " "${BUILD_INCLUDES[@]}"
    echo -e "$INCLUDES_COLOR""$includesAsString""$RESET_COLOR"
fi

if [ ${#partsToBuild[@]} -ne 0 ]; then
    printf -v partsToBuildAsString -- "$BUILD_DIRECTORY/lib%s.a " "${partsToBuild[@]}"
    echo -e "$PARTS_TO_BUILD_COLOR""$partsToBuildAsString""$RESET_COLOR"
fi

for partToBuild in "${partsToBuild[@]}"; do
    source "$partToBuild/config.sh" && {
        export OUTPUT_FILE='lib'"$partToBuild"'.a'

        './build_general.sh' "$partToBuild" "$BUILD_C_FLAGS $externalLibrariesBuildCFlagsAsString" "$definesAsString" "$includesAsString"

        BUILD_STATUS=$?

        unset FILES_TO_INCLUDE FILES_TO_COMPILE
    }

    if [ $BUILD_STATUS -ne 0 ]; then
        break
    fi
done

# Build tests
if [ ${#BUILD_INCLUDES_TESTS[@]} -ne 0 ]; then
    printf -v testIncludesAsString -- "-I $SCRIPT_DIRECTORY/%s " "${BUILD_INCLUDES_TESTS[@]}"
    echo  -e "$INCLUDES_COLOR""$testIncludesAsString""$RESET_COLOR"
fi

for testToBuild in "${testsToBuild[@]}"; do
    source "$TESTS_DIRECTORY/$testToBuild/config.sh" && {
        export OUTPUT_FILE='lib'"$testToBuild"'_test.a'

        './build_general.sh' "$TESTS_DIRECTORY/$testToBuild" "$BUILD_C_FLAGS $externalLibrariesBuildCFlagsAsString" "$definesAsString" "$includesAsString""$testIncludesAsString"

        BUILD_STATUS=$?

        unset FILES_TO_INCLUDE FILES_TO_COMPILE
    }

    if [ $BUILD_STATUS -ne 0 ]; then
        break
    fi
done

# Build tests main package
if [ $BUILD_STATUS -eq 0 ]; then
    source "$testsMainPackage/config.sh" && {
        export OUTPUT_FILE='lib'"$testsMainPackage"'.a'

        './build_general.sh' "$testsMainPackage" "$BUILD_C_FLAGS $externalLibrariesBuildCFlagsAsString" "$definesAsString" "$includesAsString""$testIncludesAsString"

        BUILD_STATUS=$?

        unset FILES_TO_INCLUDE FILES_TO_COMPILE
    }
fi

if [ $BUILD_STATUS -eq 0 ]; then
    if [ ${#testsToBuild[@]} -ne 0 ]; then
        printf -v testsToBuildAsString -- "$BUILD_DIRECTORY/lib%s_test.a " "${testsToBuild[@]}"
        echo  -e "$PARTS_TO_BUILD_COLOR""$testsToBuildAsString""$RESET_COLOR"
    fi

    if [ ${#LIBRARIES_TO_LINK_TESTS[@]} -ne 0 ]; then
        printf -v testsLibrariesToLinkAsString -- "-l%s " "${LIBRARIES_TO_LINK_TESTS[@]}"
        echo  -e "$LIBRARIES_COLOR""$testsLibrariesToLinkAsString""$RESET_COLOR"
    fi

    $C_COMPILER $LINK_FLAGS '-Wl,--whole-archive' "$BUILD_DIRECTORY/"'lib'"$testsMainPackage"'.a' $testsToBuildAsString $partsToBuildAsString '-Wl,--no-whole-archive' $librariesToLinkAsString $externalLibrariesLinkFlagsAsString $testsLibrariesToLinkAsString -o "$BUILD_DIRECTORY/$EXECUTABLE_NAME_TESTS"
    echo  -e "$BUILT_EXECUTABLE_COLOR""$EXECUTABLE_NAME_TESTS""$RESET_COLOR"
fi

}
