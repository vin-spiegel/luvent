.PHONY : docs tests

all: docs tests

# We generate documentation via the LuaDoc tool but the directory
# where we store the documents may not exist.  This rule creates the
# documentation directory if it is not present.  LuaDoc will also spit
# out a 'luadoc.css' file into the top-level directory which we do not
# want to keep.  This rule will delete it.
docs:
	if test ! -d "docs/"; then mkdir "docs"; fi
	luadoc -d "docs/" "src/Luvent.lua"
	if test -f "luadoc.css"; then rm "luadoc.css"; fi

tests:
	busted
